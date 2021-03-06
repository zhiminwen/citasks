require 'gitlab'
require 'securerandom'
require "erb"
require "rest-client"
require "pp"

def _write fullpath, content
  File.open fullpath, "w" do |fh|
    fh.puts content
  end
end

def token_shared_persistently
  #create a shared token across tasks
  secret_token_file = ".token"
  if File.exists? secret_token_file
    token = File.read(secret_token_file).chomp
  else
    token = SecureRandom.uuid
    File.open secret_token_file, "w" do |fh|
      fh.puts token
    end
  end
  token
end

module JenkinsTools
  WORKFLOW_PLUGIN = ENV["WORKFLOW_PLUGIN"] || "workflow-job"
  GITLAB_PLUGIN = ENV["GITLAB_PLUGIN"] || "gitlab-plugin"
  WORkFLOW_CPS_PLUGIN = ENV["WORkFLOW_CPS_PLUGIN"] || "workflow-cps"
  GIT_PLUGIN = ENV["GIT_PLUGIN"] || "git"
  # JENKIN_PROJECT_ENDPOINT_AUTHENTICATION = ENV["JENKIN_PROJECT_ENDPOINT_AUTHENTICATION"].to_s.upcase == "TRUE"

  # git_repo_url = http://virtuous-porcupine-gitlab-ce/wenzm/icp-static-web.git, gitlab-wenzm-password
  def self.gen_job_xml job_name, xml_file_name, git_repo_url, repo_credential_id_in_jenkins, secret_token=nil
    enable_secret_token = true

    if enable_secret_token
      secret_token = token_shared_persistently if secret_token.nil?
    end

    token_to_trigger_build_remotely = SecureRandom.uuid
    erb = ERB.new <<~EOF
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
                <% if enable_secret_token %>
                <secretToken><%= secret_token %></secretToken>
                <% end %>
              </com.dabsquared.gitlabjenkins.GitLabPushTrigger>
            </triggers>
          </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
        </properties>
        <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="#{WORkFLOW_CPS_PLUGIN}">
          <scm class="hudson.plugins.git.GitSCM" plugin="#{GIT_PLUGIN}">
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

    _write xml_file_name, erb.result(binding)
  end

  def self.gen_jenkins_file
    _write "Jenkinsfile", <<~EOF
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
          stage('check out') {
            checkout scm
          }

          stage('compile'){
            container('compiler'){
              sh "echo compile"
            }
          }

          stage('Docker Build'){
            container('citools'){
              // sleep 3600
              sh "echo build docker image"
              // sh "rake -f build.rb docker:01_build_image docker:02_push_to_ICp_registry"
            }
          }

          stage('Deploy to ICP'){
            container('citools'){
              // sleep 3600
              echo "deploy to icp..."
              // sh "rake -f build.rb k8s:01_deploy_to_k8s"
            }
          }

          //stage('Deployment'){
          //  parallel 'deploy to icp': {
          //    container('citools'){
          //      echo "deploy to icp..."
          //      // sh "rake -f build.rb k8s:01_deploy_to_k8s"

          //    }
          //  },

          //  'deploy to others': {
          //    container('citools'){
          //      echo "deploy to others..."
          //    }
          //  }
          //}
        }
      }
    EOF
  end

  def self.post_new_job job_name, xml_file, base_url, user, token
    # system %Q(curl -s -XPOST "#{base_url}/createItem?name=#{job_name}" --data-binary "@#{xml_file}" -H "Content-Type:text/xml" --user "#{user}:#{token}")
    req = RestClient::Request.new(
      method: :post,
      user: user,
      password: token,
      url: "#{base_url}/createItem?name=#{job_name}",
      timeout: 30,
      headers: {
        "Content-Type" => "text/xml",
      },
      payload: File.read(xml_file)
    )

    begin
      res = req.execute
    rescue RestClient::ExceptionWithResponse => err
      case err.http_code
      when 301, 302, 307
        err.response.follow_redirection
      else
        raise
      end
    end

  end

  def self.download_job job_name, xml_file, base_url, user, token
    # system %Q(curl -s "#{base_url}/job/#{job_name}/config.xml" -o #{xml_file} --user "#{user}:#{token}")
    req = RestClient::Request.new(
      method: :get,
      user: user,
      password: token,
      url: "#{base_url}/job/#{job_name}/config.xml",
      timeout: 30
    )

    res = req.execute

    File.open xml_file, "w" do |fh|
      fh.puts res.body
    end
  end

  def self.delete! job_name, base_url, user, token
    # system %Q(curl -XPOST "#{base_url}/job/#{job_name}/doDelete" --user "#{user}:#{token}")
    req = RestClient::Request.new(
      method: :post,
      user: user,
      password: token,
      url: "#{base_url}/job/#{job_name}/doDelete",
      timeout: 30
    )

    begin
      res = req.execute
    rescue RestClient::ExceptionWithResponse => err
      case err.http_code
      when 301, 302, 307
        err.response.follow_redirection
      else
        raise
      end
    end
  end

  def self.trigger_build job_name,build_token, base_url
    # system %Q(curl "#{base_url}/job/#{job_name}/build?token=#{build_token}")
    req = RestClient::Request.new(
      method: :get,
      url: "#{base_url}/job/#{job_name}/build?token=#{build_token}",
      timeout: 30
    )
    res = req.execute
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

  def self.setup_hook repo_name, gitlab_url, token, hooked_url, secret_token=nil
    _setup_gitlab gitlab_url, token

    project = Gitlab.projects.find do |p|
      p.name== repo_name
    end

    secret_token = token_shared_persistently if secret_token.nil?

    Gitlab.add_project_hook project.id, hooked_url, :push_events => 1,:enable_ssl_verification=>0, :token=> secret_token

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
    _write ".env.build", <<~EOF
      IMAGE_NAME=#{app_name}

      PRIVATE_DOCKER_REGISTRY_NAME=#{ENV["ICP_REGISTRY_HOSTNAME"]}
      PRIVATE_DOCKER_REGISTRY_PORT=8500
      PRIVATE_DOCKER_REGISTRY_IP=#{ENV["ICP_MASTER_IP"]}
      PRIVATE_DOCKER_REGISTRY_NAMESPACE=#{ENV["PRIVATE_DOCKER_REGISTRY_NAMESPACE"]}

      PRIVATE_DOCKER_REGISTRY_USER=admin
      PRIVATE_DOCKER_REGISTRY_USER_PASSWORD=admin

      PRIVATE_DOCKER_REGISTRY_PULL_SECRET=#{ENV["IMAGE_PULL_SECRET"]}

      K8S_NAMESPACE=#{ENV["K8S_NAMESPACE"]}
    EOF
  end

  def self.create_lib_files
    FileUtils.mkdir_p lib_dir = "build_libs"

    _write lib_dir + "/helpers.rb", <<~EOF
      require "yaml"

      require_relative "docker.rb"
      require_relative "k8s.rb"

      @task_index=0
      def next_task_index
        @task_index += 1
        sprintf("%02d", @task_index)
      end

      def reset_task_index
        @task_index = 0
      end
    EOF

    _write lib_dir + "/shell.rb", <<~EOF
      module ShellCommandConstructor
        def self.construct_command strings_or_list, connector = " && "
          list = case strings_or_list
          when Array
            strings_or_list
          when String
            strings_or_list.split(/\\n/)
          end
          list.each_with_object([]) do |line, obj|
              line.strip!
              next if line.empty?
              next if line =~ /^#/
              obj.push line
          end.join connector
        end
      end

      module Shell
        def self.run cmd
          unless system(cmd)
            fail "Failed to execute \#{cmd}"
          end
        end

        def self.test cmd
          system cmd
        end
      end
    EOF

    _write lib_dir + "/docker.rb", <<~EOF
      require_relative "shell"

      module DockerTools
        def self.add_etc_hosts
          etc_hosts_entry = sprintf("%s %s", ENV["PRIVATE_DOCKER_REGISTRY_IP"], ENV["PRIVATE_DOCKER_REGISTRY_NAME"])
          Shell.run %Q(echo "\#{etc_hosts_entry}" >> /etc/hosts)
        end

        def self.push_to_registry image_name, tag
          private_registry = sprintf("%s:%s", ENV["PRIVATE_DOCKER_REGISTRY_NAME"], ENV["PRIVATE_DOCKER_REGISTRY_PORT"])
          namespace = ENV["PRIVATE_DOCKER_REGISTRY_NAMESPACE"]

          cmds = ShellCommandConstructor.construct_command %Q{
            docker login -u \#{ENV["PRIVATE_DOCKER_REGISTRY_USER"]} -p \#{ENV["PRIVATE_DOCKER_REGISTRY_USER_PASSWORD"]} \#{private_registry}

            docker tag \#{image_name}:\#{tag} \#{private_registry}/\#{namespace}/\#{image_name}:\#{tag}
            docker push \#{private_registry}/\#{namespace}/\#{image_name}:\#{tag}
          }
          Shell.run cmds
        end
      end
    EOF

    _write lib_dir + '/k8s.rb', <<~EOF
      require "erb"
      require_relative "shell"

      module KubeTools
        def self.create_namespace namespace
          Shell.run %Q(kubectl create namespace \#{namespace} || echo ignore exists error)
        end

        def self.create_pull_secret namespace, user, pass, secret_name
          Shell.run %Q(kubectl delete secret \#{secret_name} -n \#{namespace} || echo ignore non exists error)
          Shell.run %Q(kubectl create secret docker-registry \#{secret_name} -n \#{namespace} --docker-server=\#{ENV["PRIVATE_DOCKER_REGISTRY_NAME"]}:\#{ENV["PRIVATE_DOCKER_REGISTRY_PORT"]} --docker-username=\#{ENV["PRIVATE_DOCKER_REGISTRY_USER"]} --docker-password=\#{ENV["PRIVATE_DOCKER_REGISTRY_USER_PASSWORD"]} --docker-email=\#{ENV["PRIVATE_DOCKER_REGISTRY_USER"]}@\#{ENV["PRIVATE_DOCKER_REGISTRY_NAME"]})
        end


        def self.create_new_yaml yaml_template_file, yaml_file, data = {}
          erb = ERB.new(File.read(yaml_template_file))
          b = binding

          data.each_pair do |key, value|
            b.local_variable_set(key, value)
          end

          File.open yaml_file, "w" do |fh|
            fh.puts erb.result(b)
          end
        end

        def self.deploy_to_k8s yaml_file
          Shell.run %Q(kubectl apply -f \#{yaml_file})
        end
      end
    EOF

  end

  def self.create_rakefile
    _write "build.rb", <<~OUTEOF
      require 'dotenv'
      Dotenv.load ".env.build"
      require_relative "build_libs/helpers"

      image_name = ENV["IMAGE_NAME"]
      tag=ENV["BUILD_NUMBER"]||"B1"

      namespace "docker" do
        reset_task_index

        desc "build docker image"
        task "\#{next_task_index}_build_image" do
          sh %Q(docker build -t \#{image_name}:\#{tag} .)
        end

        desc "push to ICp registry"
        task "\#{next_task_index}_push_to_ICp_registry" do
          DockerTools.add_etc_hosts
          KubeTools.create_namespace ENV["K8S_NAMESPACE"]
          DockerTools.push_to_registry image_name, tag
        end
      end

      namespace "k8s" do
        reset_task_index

        desc "deploy into k8s"
        task "\#{next_task_index}_deploy_to_k8s" do
          KubeTools.create_pull_secret ENV["K8S_NAMESPACE"], ENV["PRIVATE_DOCKER_REGISTRY_USER"], ENV["PRIVATE_DOCKER_REGISTRY_USER_PASSWORD"], ENV["PRIVATE_DOCKER_REGISTRY_PULL_SECRET"]

          yaml_template_file = "\#{image_name}.k8.template.yaml"
          yaml_file = "\#{image_name}.yaml"

          private_registry = sprintf("%s:%s", ENV["PRIVATE_DOCKER_REGISTRY_NAME"], ENV["PRIVATE_DOCKER_REGISTRY_PORT"])
          namespace = ENV["PRIVATE_DOCKER_REGISTRY_NAMESPACE"]

          full_new_image_name = "\#{private_registry}/\#{namespace}/\#{image_name}:\#{tag}"
          data = {
            new_image: full_new_image_name
          }

          KubeTools.create_new_yaml yaml_template_file, yaml_file, data

          KubeTools.deploy_to_k8s yaml_file
        end
      end
    OUTEOF
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

  def self.create_k8_file namespace, app_name, pull_secret=ENV["IMAGE_PULL_SECRET"]
    _write "#{app_name}.k8.template.yaml", <<~EOF
      apiVersion: extensions/v1beta1
      kind: Deployment
      metadata:
        namespace: #{namespace}
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
              image: <%= new_image %>
            imagePullSecrets:
            - name: #{pull_secret}
      ---
      apiVersion: v1
      kind: Service
      metadata:
        namespace: #{namespace}
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
        namespace: #{namespace}
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
  end
end