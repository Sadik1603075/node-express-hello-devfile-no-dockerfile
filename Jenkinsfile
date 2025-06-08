pipeline {
    agent any

    environment {
        IMAGE_NAME = "hello-node"
        REGISTRY_URL = "localhost:5001"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        FULL_IMAGE = "${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
    }

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Sadik1603075/node-express-hello-devfile-no-dockerfile.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image: ${FULL_IMAGE}"
                    sh "docker build -t ${FULL_IMAGE} ."
                }
            }
        }

        stage('Push to Local Registry') {
            steps {
                script {
                    echo "Pushing image to ${REGISTRY_URL}"
                    sh "docker push ${FULL_IMAGE}"
                }
            }
        }

        stage('Pull & Run Image (Test)') {
            steps {
                script {
                    echo "Testing pulled image..."
                    sh """
                        docker pull ${FULL_IMAGE}
                        docker run -d --rm -p 8081:8080 --name app-container ${FULL_IMAGE}
                        sleep 5
                        curl -f http://localhost:8081 || (echo 'App did not respond' && exit 1)
                        docker stop app-container
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
        always {
            echo "Cleaning up dangling Docker images..."
            sh "docker image prune -f"
        }
    }
}
