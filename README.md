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
minikube start -p 0311ta --driver=docker \
  --mount \
  --mount-string="$(pwd):/static-website"
```
4. Aplicar los manifiestos de Kubernetes:
```shell
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```
5. Verificar que los pods estén corriendo:
```shell
kubectl get pods
```
6. Espera a que la columna de `STATUS` diga `1/1`.
7. Ahora podemos acceder a la página web:
```shell
minikube service web-static-service -p 0311at
```
### Aclaraciones
El contenido se sirve desde un volumen persistente, lo que permite reiniciar el pod sin perder los archivos clonados.
El git clone es realizado automáticamente por un initContainer al iniciar el pod.
Este enfoque simula un entorno de producción donde el contenido se mantiene separado del contenedor Nginx base.