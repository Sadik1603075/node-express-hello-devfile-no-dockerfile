# Jenkins Setup

https://www.jenkins.io/doc/book/installing/docker/ documentation was followed  to setup Jenkins on ubuntu  machine. Installation contain the following steps;

1. Create a bridge network in Docker using the following `docker network create` command:

```
docker network create jenkins
```
2. In order to execute Docker commands inside Jenkins nodes, download and run the `docker:dind` Docker image using the following docker run command:

```
docker run \
  --name jenkins-docker \
  --rm \
  --detach \
  --privileged \
  --network jenkins \
  --network-alias docker \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume jenkins-docker-certs:/certs/client \
  --volume jenkins-data:/var/jenkins_home \
  --publish 2376:2376 \
  docker:dind \
  --storage-driver overlay2
```

3. Customize the official Jenkins Docker image, by executing the following two steps:

  a. Create a Dockerfile with the following content:
  
    ```
        FROM jenkins/jenkins:2.504.2-jdk21
        USER root
        RUN apt-get update && apt-get install -y lsb-release ca-certificates curl && \
            install -m 0755 -d /etc/apt/keyrings && \
            curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
            chmod a+r /etc/apt/keyrings/docker.asc && \
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
            https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
            | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
            apt-get update && apt-get install -y docker-ce-cli && \
            apt-get clean && rm -rf /var/lib/apt/lists/*
        USER jenkins
        RUN jenkins-plugin-cli --plugins "blueocean docker-workflow json-path-api"
    ```

  b. Build a new docker image from this Dockerfile, and assign the image a meaningful name, such as "myjenkins-blueocean:2.504.2-1":
    ```
      docker build -t myjenkins-blueocean:2.504.2-1 .
    ```

4. Run your own `myjenkins-blueocean:2.504.2-1` image as a container in Docker using the following docker run command:

  ```
   docker run --name jenkins-blueocean --restart=on-failure --detach --network jenkins --publish 8080:8080 --publish 50000:50000 -v /var/run/docker.sock:/var/run/docker.sock myjenkins-blueocean:2.504.2-1
  ```
# Dockerfile

5. Created multi-stage production grade Dockerfile for this app.

  ```
    FROM node:lts-alpine3.22 AS build
  ```
  a. Build stage: used `node:lts-alpine3.22` official image, Alias this stage as `build` to referenc it later.

  ```
    WORKDIR /usr/src/app
  ```
  b. Set the working directory `/usr/src/app` inside the container. All the following command of this stage will be executed from this directory of the container.

  ```
    COPY package*.json ./
    RUN npm install --only=production
  ```
  c. copied package.json & package-lock.json only and installed only production dependencies, skipping dev dependencies to reduce image size.

  ```
    COPY . .
  ```

  d. copied rest of the source code into container's workdir, used .dockerignore to skip unwanted files.

  ```
    FROM node:lts-alpine3.22 AS runtime
    WORKDIR /usr/src/app
    COPY --from=build /usr/src/app .
  ```
  e. Started a new stage and copied the built app, including `node_modules`from the build stage into the current container.

  ```
    ENV NODE_ENV=production
    ENV PORT=3000
  ```
  f. Defined app environment and default port.

  ```
    EXPOSE 3000
    CMD ["node", "app.js"]
  ```
  g. Exposed port 3000 and run the app.

# Pipeline

6. Created Jenkinsfile to automate the CD process.
  ```
        agent any
  ```
  a. Set to run the pipeline on any available Jenkins agent.

  ```
    environment {
    IMAGE_NAME = "hello-node" # Name of the Docker image
    REGISTRY_URL = "localhost:5001" # URL of  local Docker registry (on port 5001)
    IMAGE_TAG = "${env.BUILD_NUMBER}" # Uses the Jenkins build number for versioning
    FULL_IMAGE = "${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}" # Full image name including tag and registry URL
    }
  ```
  b. Set environment variable to resue in the pipeline code.

  ```
    stage('Clone Repository') {
    steps {
        git branch: 'main', url: 'https://github.com/Sadik1603075/node-express-hello-devfile-no-dockerfile.git'
      }
    }
  ```
  c. Clone the repository from git branch `main`.

  ```
    stage('Build Docker Image') {
      steps {
          script {
              echo "Building Docker image: ${FULL_IMAGE}"
              sh "docker build -t ${FULL_IMAGE} ."
          }
      }
    }
  ```
  d. Build the docker image. Note using FULL_IMAGE name.

  ```
    stage('Push to Local Registry') {
      steps {
          script {
              echo "Pushing image to ${REGISTRY_URL}"
              sh "docker push ${FULL_IMAGE}"
          }
        }
    }
  ```
  e. Pushed the new image into local docker registry which is running on port 5001.

  ```
     stage('Pull & Run Image (Test)') {
        steps {
            script {
                echo "Testing pulled image..."
                sh """
                    docker pull ${FULL_IMAGE}
                    if [ \$(docker ps -a -q -f name=app-container) ]; then
                      docker rm -f app-container
                    fi
                    docker run -d --rm -p 8081:3000 --name app-container ${FULL_IMAGE}
                    sleep 5
                    curl -f http://localhost:8081 || { echo 'App did not respond'; exit 1; }
                """
            }
        }
      }
  ```

  f. Pulled the newly created image from docker registry, Runs the app in a container on port 8081,   Uses curl to verify the app response.


7. Setup manual production deployemnt from Jenkins web UI. (Note: it's possible to setup push/ Poll based deployment)

8. Fetched the admin password from `jenkins-blueocean` container's `/var/jenkins_home/secrets` directory to log into Jenkins web UI. Using the following commands:

```
docker exec -it jenkins-blueocean sh
cd /var/jenkins_home/secrets
cat initialAdminPassword
```
9. Created a pipeline from Jenkins web UI using forked git repository **URL** and targeting branch **main**.

```
  getent group docker
  docker exec -u 0 -it jenkins-blueocean bash
  groupadd -g 1001 docker (Note use the GID returned from: getent group docker)
  usermod -aG docker jenkins
  exit
  docker restart jenkins-blueocean
```

10. Created a matching docker group inside the container using the following commands. Note: Need to match the group ID (GID) of the host's docker group inside the container so that the container's user (jenkins) can access the host's Docker socket (/var/run/docker.sock) with proper permissions.



# Docker Regsitry

```
docker run -d \
  -p 5001:5000 \
  --name local-registry \
  -v /opt/app-images:/var/lib/registry \
  --restart=always \
  registry:2
```
11. Used the following command to create a docker registry on port 5001. All pushed images are saved under /opt/app-images on host machine.

# Issues 

```
permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock

```
1. Jenkins container doesn't have permission to access Docker socket. Resolved this issue by point 10.

2. Host Port 5000 is used by a process, that's why created a docker registry at port 5001.
