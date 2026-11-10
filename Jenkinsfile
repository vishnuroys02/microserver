pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  triggers {
    pollSCM('* * * * *')
  }

  environment {
    AWS_DEFAULT_REGION = 'ap-southeast-2'
    REGISTRY           = '024899755048.dkr.ecr.ap-southeast-2.amazonaws.com'
    EC2_HOST           = '32.236.188.119'
    SERVICES           = 'user product order'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          def sha = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${sha}"
        }
        echo "Image tag: ${env.IMAGE_TAG}"
      }
    }

    stage('Validate Config') {
      steps {
        sh '''
          REGISTRY=x IMAGE_TAG=y docker compose -f docker-compose.prod.yml config > /dev/null
          docker compose -f docker-compose.yml config > /dev/null
          echo "Compose files valid"
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          for s in $SERVICES; do
            echo "Testing $s-service"
            docker run --rm -v "$PWD/$s-service":/app -w /app node:20-alpine npm test
          done
        '''
      }
    }

    stage('Build and Tag') {
      steps {
        sh '''
          for s in $SERVICES; do
            docker build -t $REGISTRY/$s-service:$IMAGE_TAG ./$s-service
          done
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        withCredentials([
          string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
          string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
        ]) {
          sh '''
            aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $REGISTRY
            for s in $SERVICES; do
              docker push $REGISTRY/$s-service:$IMAGE_TAG
            done
          '''
        }
      }
    }

    stage('Deploy to EC2') {
      steps {
        script { env.DEPLOY_STARTED = 'true' }
        sshagent(credentials: ['ec2-ssh-key']) {
          sh '''
            OPTS="-o StrictHostKeyChecking=accept-new"
            ssh $OPTS ubuntu@$EC2_HOST "mkdir -p ~/app/nginx"
            ssh $OPTS ubuntu@$EC2_HOST "cd ~/app && if [ -f .env ]; then cp .env .env.previous; fi"
            scp $OPTS docker-compose.prod.yml ubuntu@$EC2_HOST:~/app/docker-compose.yml
            scp $OPTS nginx/default.conf ubuntu@$EC2_HOST:~/app/nginx/default.conf
            ssh $OPTS ubuntu@$EC2_HOST "cd ~/app && echo REGISTRY=$REGISTRY > .env && echo IMAGE_TAG=$IMAGE_TAG >> .env"
            ssh $OPTS ubuntu@$EC2_HOST "cd ~/app && aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $REGISTRY"
            ssh $OPTS ubuntu@$EC2_HOST "cd ~/app && docker compose pull && docker compose up -d --remove-orphans"
          '''
        }
      }
    }

    stage('Verify Deployment') {
      steps {
        sh '''
          ok=0
          for i in $(seq 1 12); do
            if curl -fsS http://$EC2_HOST/health > /dev/null; then ok=1; break; fi
            echo "Waiting for nginx... ($i)"
            sleep 5
          done
          [ "$ok" = "1" ] || exit 1
          for s in $SERVICES; do
            curl -fsS http://$EC2_HOST/api/$s/health
            echo
          done
        '''
      }
    }
  }

  post {
    success {
      echo "Deployed ${env.IMAGE_TAG} to ${env.EC2_HOST}"
    }
    failure {
      script {
        if (env.DEPLOY_STARTED == 'true') {
          echo 'Deployment failed, rolling back to previous version'
          sshagent(credentials: ['ec2-ssh-key']) {
            sh '''
              ssh -o StrictHostKeyChecking=accept-new ubuntu@$EC2_HOST "cd ~/app && if [ -f .env.previous ]; then cp .env.previous .env && docker compose up -d; else echo no previous version; fi"
            '''
          }
        } else {
          echo 'Failed before deployment, nothing to roll back'
        }
      }
    }
    always {
      sh 'docker image prune -f || true'
    }
  }
}
