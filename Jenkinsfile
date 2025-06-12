pipeline {
    agent any

    stages {
        stage('Load Environment Variables') {
            steps {
                script {
                    def props = readProperties file: 'env-production.properties'
                    env.IMAGE_NAME = props.IMAGE_NAME
                    env.REGISTRY_URL = props.REGISTRY_URL
                    env.IMAGE_TAG = env.BUILD_NUMBER
                    env.FULL_IMAGE = "${env.REGISTRY_URL}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                }
            }
        }

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
                    catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                        echo "Testing pulled image..."
                        sh """
                            docker pull ${FULL_IMAGE}
                            if [ \$(docker ps -a -q -f name=app-container) ]; then
                            docker stop app-container
                            sleep 2
                            docker rm -f app-container
                            fi
                            docker run -d --rm  -p 8081:3000 --name app-container ${FULL_IMAGE}
                        """
                    }
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
