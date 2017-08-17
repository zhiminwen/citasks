require 'gitlab'
require 'securerandom'

module JenkinsTools
  WORKFLOW_PLUGIN = ENV["WORKFLOW_PLUGIN"] || "workflow-job@2.14.1"
  GITLAB_PLUGIN = ENV["GITLAB_PLUGIN"] || "gitlab-plugin@1.4.7"
  WORkFLOW_CPS_PLUGIN = ENV["WORkFLOW_CPS_PLUGIN"] || "workflow-cps@2.39"
  GIT_PLUGIN = ENV["GIT_PLUGIN"] || "git@3.4.0"
  
  # git_repo_url = http://virtuous-porcupine-gitlab-ce/wenzm/icp-static-web.git, gitlab-wenzm-password
  def self.gen_job_xml job_name, xml_file_name, git_repo_url, repo_credential_id_in_jenkins,token_to_trigger_build_remotely = SecureRandom.uuid
    secret_token = "{AQAAABAAAAAQ76W/e/wjLSZ6yxDaU6oaB3rUABFZ/jw6NVzpJkLGL/8=}" #empty??? TODO
    xmls= <<~EOF
      <?xml version='1.0' encoding='UTF-8'?>
      <flow-definition plugin="#{WORKFLOW_PLUGIN}">
        <actions/>
        <description>Workflow Created with template</description>
        <keepDependencies>false</keepDependencies>
        <properties>
          <com.dabsquared.gitlabjenkins.connection.GitLabConnectionProperty plugin="#{GITLAB_PLUGIN}">
            <gitLabConnection>gitlab</gitLabConnection>
          </com.dabsquared.gitlabjenkins.connection.GitLabConnectionProperty>
          <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
            <triggers>
              <com.dabsquared.gitlabjenkins.GitLabPushTrigger plugin="#{GITLAB_PLUGIN}">
                <spec></spec>
                <triggerOnPush>true</triggerOnPush>
                <triggerOnMergeRequest>false</triggerOnMergeRequest>
                <triggerOnAcceptedMergeRequest>false</triggerOnAcceptedMergeRequest>
                <triggerOnClosedMergeRequest>false</triggerOnClosedMergeRequest>
                <triggerOpenMergeRequestOnPush>never</triggerOpenMergeRequestOnPush>
                <triggerOnNoteRequest>true</triggerOnNoteRequest>
                <noteRegex>Jenkins please build one more</noteRegex>
                <ciSkip>true</ciSkip>
                <skipWorkInProgressMergeRequest>true</skipWorkInProgressMergeRequest>
                <setBuildDescription>true</setBuildDescription>
                <branchFilterType>All</branchFilterType>
                <includeBranchesSpec></includeBranchesSpec>
                <excludeBranchesSpec></excludeBranchesSpec>
                <targetBranchRegex></targetBranchRegex>
                <!-- <secretToken>#{secret_token}</secretToken> -->
              </com.dabsquared.gitlabjenkins.GitLabPushTrigger>
            </triggers>
          </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
        </properties>
        <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="#{WORkFLOW_CPS_PLUGIN}">
          <scm class="hudson.plugins.git.GitSCM" plugin="#[GIT_PLUGIN}">
            <configVersion>2</configVersion>
            <userRemoteConfigs>
              <hudson.plugins.git.UserRemoteConfig>
                <url>#{git_repo_url}</url>
                <credentialsId>#{repo_credential_id_in_jenkins}</credentialsId>
              </hudson.plugins.git.UserRemoteConfig>
            </userRemoteConfigs>
            <branches>
              <hudson.plugins.git.BranchSpec>
                <name>*/master</name>
              </hudson.plugins.git.BranchSpec>
            </branches>
            <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
            <submoduleCfg class="list"/>
            <extensions/>
          </scm>
          <scriptPath>Jenkinsfile</scriptPath>
          <lightweight>true</lightweight>
        </definition>
        <triggers/>
        <authToken>#{token_to_trigger_build_remotely}</authToken>
        <disabled>false</disabled>
      </flow-definition>
    EOF

    File.open xml_file_name, "w" do |fh|
      fh.puts xmls
    end

  end

  def self.gen_jenkins_file
    content= <<~EOF
      //A Jenkinsfile for start
      podTemplate(label: 'my-pod',
        containers:[
          containerTemplate(name: 'compiler', image:'#{ENV["COMPILER_DOCKER_IMAGE"]}',ttyEnabled: true, command: 'cat', envVars:[
              containerEnvVar(key: 'BUILD_NUMBER', value: env.BUILD_NUMBER),
              containerEnvVar(key: 'BUILD_ID', value: env.BUILD_ID),
              containerEnvVar(key: 'BUILD_URL', value: env.BUILD_URL),
              containerEnvVar(key: 'BUILD_TAG', value: env.BUILD_TAG),
              containerEnvVar(key: 'JOB_NAME', value: env.JOB_NAME)
            ],
          ),
          containerTemplate(name: 'citools', image:'zhiminwen/citools',ttyEnabled: true, command: 'cat', envVars:[
              // these env is only available in container template? podEnvVar deosn't work?!
              containerEnvVar(key: 'BUILD_NUMBER', value: env.BUILD_NUMBER),
              containerEnvVar(key: 'BUILD_ID', value: env.BUILD_ID),
              containerEnvVar(key: 'BUILD_URL', value: env.BUILD_URL),
              containerEnvVar(key: 'BUILD_TAG', value: env.BUILD_TAG),
              containerEnvVar(key: 'JOB_NAME', value: env.JOB_NAME)
            ],
          )
        ],
        volumes: [
          //for docker to work
          hostPathVolume(hostPath: '/var/run/docker.sock', mountPath: '/var/run/docker.sock')
        ]
      ){
        node('my-pod') {
          stage('clone git repo'){
            checkout scm

            container('compiler'){
             stage('Compile and Build'){
               sh("echo compile")
             }
            }

            container('citools'){
              stage('Docker Build'){
                // sleep 3600
                sh "echo build docker image"
                // sh "rake -f build.rb docker:01_build_image docker:02_push_to_ICp_registry"  
              }

              stage('Deploy into k8s'){
                sh "echo rollout to k8s" 
                // sh "rake -f build.rb k8s:01_deploy_to_k8s"
              }
            }
          }
        }
      }    
    EOF
    
    File.open "Jenkinsfile", "w" do |fh|
      fh.puts content
    end
    
  end

  def self.post_new_job job_name, xml_file, base_url, user, token
    system %Q(curl -s -XPOST "#{base_url}/createItem?name=#{job_name}" --data-binary "@#{xml_file}" -H "Content-Type:text/xml" --user "#{user}:#{token}")
  end

  def self.download_job job_name, xml_file, base_url, user, token
    system %Q(curl -s "#{base_url}/job/#{job_name}/config.xml" -o #{xml_file} --user "#{user}:#{token}")
  end

  def self.delete! job_name, base_url, user, token
    system %Q(curl -XPOST "#{base_url}/job/#{job_name}/doDelete" --user "#{user}:#{token}")
  end

  def self.trigger_build job_name,build_token, base_url
    system %Q(curl "#{base_url}/job/#{job_name}/build?token=#{build_token}")
  end

end

module GitlabTools
  def self._setup_gitlab gitlab_url, token
    Gitlab.endpoint = "#{gitlab_url}/api/v4"
    Gitlab.private_token = token
  end

  def self.new_repo repo_name, gitlab_url, token
    _setup_gitlab gitlab_url, token
    Gitlab.create_project repo_name
  end

  def self.setup_hook repo_name, gitlab_url, token, hooked_url, secret_token_for_hooked_url=nil
    _setup_gitlab gitlab_url, token

    project = Gitlab.projects.find do |p|
      p.name== repo_name
    end
    
    Gitlab.add_project_hook project.id, hooked_url, :push_events => 1,:enable_ssl_verification=>0, :token=> secret_token_for_hooked_url

  end

  def self.delete! repo_name, gitlab_url, token
    _setup_gitlab gitlab_url, token

    project = Gitlab.projects.find do |p|
      p.name== repo_name
    end
    if project.nil?
      puts "repo #{repo_name} doesn't exists" 
      return
    end

    Gitlab.delete_project project.id
  end
end

module Builder
  def self.create_env app_name
    envs = <<~EOF
      IMAGE_NAME=#{app_name}
      
      PRIVATE_DOCKER_REGISTRY_NAME=master.cfc
      PRIVATE_DOCKER_REGISTRY_PORT=8500
      PRIVATE_DOCKER_REGISTRY_IP=#{ENV["ICP_MASTER_IP"]}
      
      PRIVATE_DOCKER_REGISTRY_USER=admin
      PRIVATE_DOCKER_REGISTRY_USER_PASSWORD=admin

    EOF

    File.open ".env.build", "w" do |fh|
      fh.puts envs
    end
  end

  def self.create_rakefile
    content = <<~OUTEOF
      require 'sshkit_addon'
      require 'dotenv'
      require "yaml"

      Dotenv.load ".env.build"

      @task_index=0
      def next_task_index
        @task_index += 1
        sprintf("%02d", @task_index)
      end

      image_name = ENV["IMAGE_NAME"]
      tag=ENV["BUILD_NUMBER"]||"B1"

      namespace "docker" do
        @task_index=0
        desc "build docker image"
        task "\#{next_task_index}_build_image" do
          sh %Q(env)
          sh %Q(docker build -t \#{image_name}:\#{tag} .)
        end

        desc "push to ICp registry"
        task "\#{next_task_index}_push_to_ICp_registry" do
          etc_hosts_entry = sprintf("%s %s", ENV["PRIVATE_DOCKER_REGISTRY_IP"], ENV["PRIVATE_DOCKER_REGISTRY_NAME"])
          private_registry = sprintf("%s:%s", ENV["PRIVATE_DOCKER_REGISTRY_NAME"], ENV["PRIVATE_DOCKER_REGISTRY_PORT"])

          cmds = ShellCommandConstructor.construct_command %Q{
            echo "\#{etc_hosts_entry}" >> /etc/hosts
            docker login -u \#{ENV["PRIVATE_DOCKER_REGISTRY_USER"]} -p \#{ENV["PRIVATE_DOCKER_REGISTRY_USER"]} \#{private_registry}
            
            docker tag \#{image_name}:\#{tag} \#{private_registry}/default/\#{image_name}:\#{tag}
            docker push \#{private_registry}/default/\#{image_name}:\#{tag}
          }
          sh cmds
        end
      end

      namespace "k8s" do
        @task_index=0
        desc "deploy into k8s"
        task "\#{next_task_index}_deploy_to_k8s" do
          file = "\#{image_name}.k8.template.yaml"
          docs = YAML.load_stream File.read(file)
          private_registry = sprintf("%s:%s", ENV["PRIVATE_DOCKER_REGISTRY_NAME"], ENV["PRIVATE_DOCKER_REGISTRY_PORT"])
          new_image_name = "\#{private_registry}/default/\#{image_name}:\#{tag}"

          File.open yaml_file = "\#{image_name}.yaml", "w" do |fh|
            docs.each do |doc|
              if doc["kind"] == "Deployment"
                doc["spec"]["template"]["spec"]["containers"][0]["image"] = new_image_name
              end
              fh.puts doc.to_yaml
            end
          end

          deployment = image_name
          sh %Q(kubectl get deployment | grep \#{deployment} ) do |ok, res|
            if ok #already exists
              sh %Q(kubectl apply -f \#{yaml_file})
              sh %Q(kubectl set image deployment/\#{deployment} \#{image_name}=\#{new_image_name})

              sh %Q(kubectl rollout status deployment/\#{deployment})
            else
              puts "no deployment yet. create it"
              sh %Q(kubectl create -f \#{yaml_file} --record)
            end
          end

        end
      end    
    OUTEOF

    File.open "build.rb", "w" do |fh|
      fh.puts content
    end
  end

  def self.create_dockerfile
    File.open "Dockerfile", "w" do |fh|
      fh.puts <<~EOF
        FROM bitnami/minideb
        ADD exe /
        ENV LISTENING_PORT 80
        
        CMD ["/exe"]
      EOF
    end
  end

  def self.create_k8_file app_name
    content = <<~EOF
      apiVersion: extensions/v1beta1
      kind: Deployment
      metadata:
        name: #{app_name}
        labels:
          app: #{app_name}
          type: jenkins-build
      spec:
        replicas: 2
        template:
          metadata:
            labels:
              app: #{app_name}
          spec:
            containers:
            - name: #{app_name}
              #this will be replaced dynamically in the deployment
              image: #{app_name}:latest
            imagePullSecrets:
            - name: admin.registrykey
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: #{app_name}
        labels:
          app: #{app_name}
      spec:
        type: NodePort
        ports:
          - port: 80
            targetPort: 80
            protocol: TCP
            name: http
        selector:
          app: #{app_name}
      ---
      apiVersion: extensions/v1beta1
      kind: Ingress
      metadata:
        name: #{app_name}-ingress
        labels:
          app: #{app_name}-ingress
      spec:
        rules:
          - host: k8s.myvm.io
            http:
              paths:
                - path: /
                  backend:
                    serviceName: #{app_name}
                    servicePort: http
    EOF

    File.open "#{app_name}.k8.template.yaml", "w" do |fh|
      fh.puts content
    end
    
  end
end