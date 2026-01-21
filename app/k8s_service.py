from kubernetes import client, config
from kubernetes.client.rest import ApiException
from typing import Dict, Optional
import yaml
from app.config import settings
from app.models import InstanceType, InstanceStatus
import logging

logger = logging.getLogger(__name__)


class KubernetesService:
    """Service for managing Kubernetes resources"""
    
    def __init__(self):
        try:
            if settings.K8S_CONFIG_PATH:
                config.load_kube_config(config_file=settings.K8S_CONFIG_PATH)
            else:
                # Try in-cluster config first, fall back to default kubeconfig
                try:
                    config.load_incluster_config()
                except:
                    config.load_kube_config()
            
            self.core_api = client.CoreV1Api()
            self.apps_api = client.AppsV1Api()
            self.custom_api = client.CustomObjectsApi()
        except Exception as e:
            logger.warning(f"Failed to load k8s config: {e}. K8s operations will fail.")
            self.core_api = None
            self.apps_api = None
            self.custom_api = None
    
    def create_namespace(self, namespace_name: str) -> bool:
        """Create a Kubernetes namespace"""
        try:
            namespace = client.V1Namespace(
                metadata=client.V1ObjectMeta(
                    name=namespace_name,
                    labels={
                        "managed-by": "cmp",
                        "cluster-namespace": "true"
                    }
                )
            )
            self.core_api.create_namespace(body=namespace)
            logger.info(f"Created namespace: {namespace_name}")
            return True
        except ApiException as e:
            if e.status == 409:  # Namespace already exists
                logger.warning(f"Namespace {namespace_name} already exists")
                return True
            logger.error(f"Failed to create namespace {namespace_name}: {e}")
            return False
    
    def delete_namespace(self, namespace_name: str) -> bool:
        """Delete a Kubernetes namespace"""
        try:
            self.core_api.delete_namespace(name=namespace_name)
            logger.info(f"Deleted namespace: {namespace_name}")
            return True
        except ApiException as e:
            if e.status == 404:  # Namespace doesn't exist
                logger.warning(f"Namespace {namespace_name} not found")
                return True
            logger.error(f"Failed to delete namespace {namespace_name}: {e}")
            return False
    
    def get_pod_manifest_template(self, instance_name: str, cpu: float, memory: float, 
                                   instance_type: InstanceType, namespace: str) -> Dict:
        """
        Generate pod manifest for container instances
        """
        manifest = {
            "apiVersion": "v1",
            "kind": "Pod",
            "metadata": {
                "name": instance_name,
                "namespace": namespace,
                "labels": {
                    "app": instance_name,
                    "managed-by": "cmp",
                    "instance-type": instance_type.value
                }
            },
            "spec": {
                "containers": [
                    {
                        "name": "main",
                        "image": "nginx:latest",  # Default image, can be customized
                        "resources": {
                            "requests": {
                                "cpu": f"{cpu}",
                                "memory": f"{int(memory * 1024)}Mi"
                            },
                            "limits": {
                                "cpu": f"{cpu}",
                                "memory": f"{int(memory * 1024)}Mi"
                            }
                        }
                    }
                ],
                "restartPolicy": "Always"
            }
        }
        return manifest
    
    def get_vm_manifest_template(self, instance_name: str, cpu: float, memory: float, namespace: str) -> Dict:
        """
        Generate VirtualMachine manifest for KubeVirt
        This assumes KubeVirt is installed in the cluster
        """
        manifest = {
            "apiVersion": "kubevirt.io/v1",
            "kind": "VirtualMachine",
            "metadata": {
                "name": instance_name,
                "namespace": namespace,
                "labels": {
                    "app": instance_name,
                    "managed-by": "cmp",
                    "instance-type": "vm"
                }
            },
            "spec": {
                "running": True,
                "template": {
                    "metadata": {
                        "labels": {
                            "kubevirt.io/vm": instance_name
                        }
                    },
                    "spec": {
                        "domain": {
                            "cpu": {
                                "cores": int(cpu)
                            },
                            "resources": {
                                "requests": {
                                    "memory": f"{int(memory)}Gi"
                                }
                            },
                            "devices": {
                                "disks": [
                                    {
                                        "name": "containerdisk",
                                        "disk": {
                                            "bus": "virtio"
                                        }
                                    }
                                ]
                            }
                        },
                        "volumes": [
                            {
                                "name": "containerdisk",
                                "containerDisk": {
                                    "image": "kubevirt/cirros-container-disk-demo"
                                }
                            }
                        ]
                    }
                }
            }
        }
        return manifest
    
    def create_instance(self, instance_name: str, cpu: float, memory: float, 
                       instance_type: InstanceType, namespace: str) -> bool:
        """Create a new instance (Pod or VM)"""
        try:
            if instance_type == InstanceType.CONTAINER:
                manifest = self.get_pod_manifest_template(instance_name, cpu, memory, instance_type, namespace)
                self.core_api.create_namespaced_pod(
                    namespace=namespace,
                    body=manifest
                )
            else:  # VM
                manifest = self.get_vm_manifest_template(instance_name, cpu, memory, namespace)
                # For VMs, we need to use dynamic client or custom API
                # For now, we'll create it as a generic k8s resource
                self.custom_api.create_namespaced_custom_object(
                    group="kubevirt.io",
                    version="v1",
                    namespace=namespace,
                    plural="virtualmachines",
                    body=manifest
                )
            return True
        except ApiException as e:
            logger.error(f"Failed to create instance {instance_name}: {e}")
            return False
    
    def delete_instance(self, instance_name: str, instance_type: InstanceType, namespace: str) -> bool:
        """Delete an instance"""
        try:
            if instance_type == InstanceType.CONTAINER:
                self.core_api.delete_namespaced_pod(
                    name=instance_name,
                    namespace=namespace
                )
            else:  # VM
                self.custom_api.delete_namespaced_custom_object(
                    group="kubevirt.io",
                    version="v1",
                    namespace=namespace,
                    plural="virtualmachines",
                    name=instance_name
                )
            return True
        except ApiException as e:
            logger.error(f"Failed to delete instance {instance_name}: {e}")
            return False
    
    def start_instance(self, instance_name: str, instance_type: InstanceType, namespace: str) -> bool:
        """Start a stopped instance"""
        if instance_type == InstanceType.VM:
            try:
                # Patch the VM to set running: true
                patch = {"spec": {"running": True}}
                self.custom_api.patch_namespaced_custom_object(
                    group="kubevirt.io",
                    version="v1",
                    namespace=namespace,
                    plural="virtualmachines",
                    name=instance_name,
                    body=patch
                )
                return True
            except ApiException as e:
                logger.error(f"Failed to start VM {instance_name}: {e}")
                return False
        else:
            # For containers (pods), we can't really "start" them
            # They need to be recreated
            logger.warning("Container instances cannot be started, they need to be recreated")
            return False
    
    def stop_instance(self, instance_name: str, instance_type: InstanceType, namespace: str) -> bool:
        """Stop a running instance"""
        if instance_type == InstanceType.VM:
            try:
                # Patch the VM to set running: false
                patch = {"spec": {"running": False}}
                self.custom_api.patch_namespaced_custom_object(
                    group="kubevirt.io",
                    version="v1",
                    namespace=namespace,
                    plural="virtualmachines",
                    name=instance_name,
                    body=patch
                )
                return True
            except ApiException as e:
                logger.error(f"Failed to stop VM {instance_name}: {e}")
                return False
        else:
            # For containers, we delete them
            return self.delete_instance(instance_name, instance_type, namespace)
    
    def get_instance_status(self, instance_name: str, instance_type: InstanceType, namespace: str) -> Optional[InstanceStatus]:
        """Get the status of an instance"""
        try:
            if instance_type == InstanceType.CONTAINER:
                pod = self.core_api.read_namespaced_pod(
                    name=instance_name,
                    namespace=namespace
                )
                phase = pod.status.phase
                if phase == "Running":
                    return InstanceStatus.RUNNING
                elif phase == "Pending":
                    return InstanceStatus.PENDING
                elif phase in ["Failed", "Unknown"]:
                    return InstanceStatus.FAILED
                else:
                    return InstanceStatus.STOPPED
            else:  # VM
                vm = self.custom_api.get_namespaced_custom_object(
                    group="kubevirt.io",
                    version="v1",
                    namespace=namespace,
                    plural="virtualmachines",
                    name=instance_name
                )
                if vm.get("spec", {}).get("running"):
                    return InstanceStatus.RUNNING
                else:
                    return InstanceStatus.STOPPED
        except ApiException as e:
            logger.error(f"Failed to get status for {instance_name}: {e}")
            return None


# Singleton instance
k8s_service = KubernetesService()

