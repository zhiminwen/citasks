require 'gitlab'

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
          // containerTemplate(name: 'compiler', image:'compiler/image',ttyEnabled: true, command: 'cat', envVars:[
          //     containerEnvVar(key: 'BUILD_NUMBER', value: env.BUILD_NUMBER),
          //     containerEnvVar(key: 'BUILD_ID', value: env.BUILD_ID),
          //     containerEnvVar(key: 'BUILD_URL', value: env.BUILD_URL),
          //     containerEnvVar(key: 'BUILD_TAG', value: env.BUILD_TAG),
          //     containerEnvVar(key: 'JOB_NAME', value: env.JOB_NAME)
          //   ],
          // ),
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

            // container('compiler'){
            //  stage('Compile and Build'){
            //    sh("echo compile")
            //  }
            // }

            container('citools'){
              stage('Docker Build'){
                // sleep 3600
                sh "echo build docker image" 
              }

              stage('Deploy into k8s'){
                sh "echo rollout to k8s" 
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
    Gitlab.delete_project repo_name
  end
end