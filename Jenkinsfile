pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  triggers { pollSCM('H/2 * * * *') }

  environment {
    AWS_REGION = 'ap-south-1'
    SERVICES   = 'user-service product-service order-service'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          def sha = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.IMAGE_TAG = "v1.${BUILD_NUMBER}-${sha}"
        }
        echo "Image tag: ${env.IMAGE_TAG}"
      }
    }

    stage('Validate Config') {
      steps {
        sh '''
          export REGISTRY=dummy IMAGE_TAG=test GRAFANA_PASSWORD=dummy
          docker compose -f docker-compose.yml config -q
          docker compose -f docker-compose.prod.yml -f docker-compose.monitoring.yml config -q
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          for s in $SERVICES; do
            docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp \
              -v "$PWD/$s":/app -w /app node:20-alpine \
              sh -c "npm install --no-audit --no-fund && npm test"
          done
        '''
      }
    }

    stage('Build & Tag') {
      steps {
        sh '''
          for s in $SERVICES; do
            docker build -t $s:$IMAGE_TAG ./$s
          done
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          REGISTRY=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
          aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY
          for s in $SERVICES; do
            docker tag $s:$IMAGE_TAG $REGISTRY/$s:$IMAGE_TAG
            docker push $REGISTRY/$s:$IMAGE_TAG
          done
          echo $REGISTRY > registry.txt
        '''
      }
    }

    stage('Deploy to EC2') {
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'KEY', usernameVariable: 'SSH_USER'),
          string(credentialsId: 'ec2-host', variable: 'EC2_HOST')
        ]) {
          sh '''
            REGISTRY=$(cat registry.txt)
            OPTS="-o StrictHostKeyChecking=accept-new -i $KEY"
            scp $OPTS docker-compose.prod.yml docker-compose.monitoring.yml scripts/deploy.sh scripts/verify.sh scripts/rollback.sh $SSH_USER@$EC2_HOST:/opt/app/
            scp -r $OPTS nginx monitoring $SSH_USER@$EC2_HOST:/opt/app/
            ssh $OPTS $SSH_USER@$EC2_HOST "bash /opt/app/deploy.sh $REGISTRY $IMAGE_TAG $AWS_REGION"
          '''
        }
      }
    }

    stage('Verify Deployment') {
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'KEY', usernameVariable: 'SSH_USER'),
          string(credentialsId: 'ec2-host', variable: 'EC2_HOST')
        ]) {
          sh 'ssh -o StrictHostKeyChecking=accept-new -i $KEY $SSH_USER@$EC2_HOST "bash /opt/app/verify.sh"'
        }
      }
    }
  }

  post {
    success { echo "Deployed ${env.IMAGE_TAG} successfully" }
    failure { echo "Pipeline FAILED at tag ${env.IMAGE_TAG}. Rollback: ssh to EC2 and run: bash /opt/app/rollback.sh" }
    always  { sh 'docker image prune -f || true' }
  }
}
