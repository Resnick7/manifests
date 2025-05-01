# 0311TA - K8S: Casi como en producción

Este proyecto despliega una página web estática personalizada en un clúster local de Kubernetes usando Minikube.

---
## Requisitos

Antes de comenzar, asegúrese de tener instalado:
- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Git](https://git-scm.com/downloads)
- Acceso a internet para clonar este repositorio.
---
## Paso a paso de como desplegar la aplicación

1. Clonar la página web estática:
`git clone https://github.com/Resnick7/static-website.git`

2. Clonar los manifiestos de este repositorio:
`git clone https://github.com/Resnick7/manifests.git`

3. Iniciar Minikube con un perfil personalizado, utilizando docker como back end y montando una carpeta local en el path que será utilizada por el volumen dentro del clúster:
```shell
minikube start -p 0311at --driver=docker \
  --mount \
  --mount-string="$(pwd):/static-website"
```
4. Aplicar los manifiestos de Kubernetes:
```shell
kubectl apply -f ./manifests/volume/pv.yaml
kubectl apply -f ./manifests/volume/pvc.yaml
kubectl apply -f ./manifests/deployment/deployment.yaml
kubectl apply -f ./manifests/service/service.yaml
```
5. Verificar que los pods estén corriendo:
```shell
kubectl get pods
```
6. Debe obtener una salida similar a:
```shell
NAME                              READY   STATUS    RESTARTS   AGE
web-static-git-6ff65ff746-h7l4k   1/1     Running   0          32s
```
7. Ahora podemos acceder a la página web:
```shell
minikube service web-static-service -p 0311at
```
### Aclaraciones
El contenido se sirve desde un volumen persistente, lo que permite reiniciar el pod sin perder los archivos clonados.
El git clone es realizado automáticamente por un initContainer al iniciar el pod.
Este enfoque simula un entorno de producción donde el contenido se mantiene separado del contenedor Nginx base.
