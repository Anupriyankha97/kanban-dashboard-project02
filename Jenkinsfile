pipeline {
    agent any

    environment {
        IMAGE_NAME = 'anupriyankha/kanban-dashboard'
        IMAGE_TAG = "${BUILD_NUMBER}"
        FULL_IMAGE = "${IMAGE_NAME}:${BUILD_NUMBER}"
        CONTAINER_NAME = 'kanban-dashboard'
        NEW_CONTAINER = 'kanban-dashboard-new'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Application') {
            steps {
                sh 'npm ci'
                sh 'npm run build'
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t ${FULL_IMAGE} .'
            }
        }

        stage('Docker Login & Push') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {
                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                        docker push ${FULL_IMAGE}
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy New Container') {
            steps {
                sh '''
                    docker pull ${FULL_IMAGE}

                    docker rm -f ${NEW_CONTAINER} 2>/dev/null || true

                    docker run -d \
                        --name ${NEW_CONTAINER} \
                        --restart unless-stopped \
                        --memory=256m \
                        --cpus=0.5 \
                        -p 8081:8080 \
                        ${FULL_IMAGE}
                '''
            }
        }

        stage('Health Check New Container') {
            steps {
                sh '''
                    echo "Waiting for new container health check..."

                    for i in 1 2 3 4 5 6 7 8 9 10; do
                        STATUS=$(docker inspect --format='{{.State.Health.Status}}' ${NEW_CONTAINER} 2>/dev/null || true)

                        echo "Health status: $STATUS"

                        if [ "$STATUS" = "healthy" ]; then
                            echo "New container is healthy."
                            exit 0
                        fi

                        sleep 5
                    done

                    echo "New container failed health check."
                    docker logs ${NEW_CONTAINER} || true
                    exit 1
                '''
            }
        }

        stage('Switch Production') {
            steps {
                sh '''
                    OLD_IMAGE=$(docker inspect --format='{{.Config.Image}}' ${CONTAINER_NAME})

                    echo "Current production image: $OLD_IMAGE"
                    echo "New production image: ${FULL_IMAGE}"

                    docker stop ${CONTAINER_NAME}
                    docker rm ${CONTAINER_NAME}

                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        --restart unless-stopped \
                        --memory=256m \
                        --cpus=0.5 \
                        -p 80:8080 \
                        ${FULL_IMAGE}

                    sleep 5

                    STATUS=$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME})

                    if [ "$STATUS" != "healthy" ]; then
                        echo "New production container failed health check."
                        docker logs ${CONTAINER_NAME} || true

                        echo "Rolling back to: $OLD_IMAGE"

                        docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

                        docker run -d \
                            --name ${CONTAINER_NAME} \
                            --restart unless-stopped \
                            --memory=256m \
                            --cpus=0.5 \
                            -p 80:8080 \
                            ${OLD_IMAGE}

                        sleep 5

                        ROLLBACK_STATUS=$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME})

                        echo "Rollback health status: $ROLLBACK_STATUS"

                        if [ "$ROLLBACK_STATUS" != "healthy" ]; then
                            echo "Rollback also failed."
                            docker logs ${CONTAINER_NAME} || true
                            exit 1
                        fi

                        exit 1
                    fi

                    docker rm -f ${NEW_CONTAINER} 2>/dev/null || true

                    echo "Production deployment successful."
                '''
            }
        }
    }

    post {
        success {
            echo "Deployment successful: ${FULL_IMAGE}"
        }

        failure {
            echo "Pipeline failed."
        }
    }
}