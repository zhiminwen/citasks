require_relative "citasks/ci_lib"
require_relative "citasks/task_index"

namespace "init" do
  @task_index = 0
  desc "create initial .env file"
  task "#{next_task_index}_env" do
    File.open ".env", "w" do |fh|
      content = <<~EOF
        GITLAB_USER = wenzm

        #URL to access out side of k8s cluster
        GITLAB_BASE_URL = http://localhost:31254
        GITLAB_IN_CLUSTER_BASE_URL = http://hopping-marsupial-gitlab-ce
        GITLAB_API_TOKEN = KDbJwWZxXYkKVmGhFSN3

        JENKINS_URL = http://localhost:30003
        JENKINS_IN_CLUSTER_URL = http://interesting-orangutan-jenkins:8080
        JENKINS_GIT_USER_CREDENTIAL_ID = gitlab-wenzm-password

        JENKINS_USER = wenzm
        JENKINS_USER_API_TOKEN = 61631c2cdad1e77fecee45798056eeeb

        JOB_NAME=icp-hybrid-was
        REPO_NAME=icp-hybrid-was

        COMPILER_DOCKER_IMAGE=maven:3.5-jdk-8

        #for private docker registry
        ICP_MASTER_IP=192.168.10.100      
      EOF
    end
  end
end

namespace "Jenkins" do
  @task_index = 0
  job_name = ENV["JOB_NAME"]

  def git_repo_url_in_cluster
    sprintf("%s/%s/%s.git",ENV["GITLAB_IN_CLUSTER_BASE_URL"], ENV["GITLAB_USER"], ENV["REPO_NAME"])
  end

  task :gen_Jenkinsfile do
    JenkinsTools.gen_jenkins_file
  end

  desc "create a new project #{job_name}"
  task "#{next_task_index}_create_new_project" do
    xml_file = job_name + ".xml"
    JenkinsTools.gen_job_xml job_name, xml_file, git_repo_url_in_cluster, ENV["JENKINS_GIT_USER_CREDENTIAL_ID"]
    JenkinsTools.post_new_job job_name, xml_file, ENV["JENKINS_URL"], ENV["JENKINS_USER"], ENV["JENKINS_USER_API_TOKEN"]

    JenkinsTools.gen_jenkins_file

    Builder.create_env job_name
    Builder.create_lib_files
    Builder.create_rakefile
    Builder.create_k8_file job_name
    Builder.create_dockerfile 
  end

  desc "delete #{job_name}"
  task "#{next_task_index}_delete" do
    JenkinsTools.delete! job_name, ENV["JENKINS_URL"], ENV["JENKINS_USER"], ENV["JENKINS_USER_API_TOKEN"]
  end
end

namespace "Gitlab" do
  @task_index = 0

  repo_name=ENV["REPO_NAME"]

  def git_repo_url
    sprintf("%s/%s/%s.git",ENV["GITLAB_BASE_URL"], ENV["GITLAB_USER"], ENV["REPO_NAME"])
  end

  desc "create a new gitlab repo of #{repo_name}"
  task "#{next_task_index}_create_new_repo" do
    GitlabTools.new_repo repo_name, ENV["GITLAB_BASE_URL"], ENV["GITLAB_API_TOKEN"]
  end

  desc "setup webhook"
  task "#{next_task_index}_webhook" do
    job_name = ENV["JOB_NAME"]
    hooked_jenkins_url = "#{ENV["JENKINS_IN_CLUSTER_URL"]}/project/#{job_name}"

    GitlabTools.setup_hook repo_name,  ENV["GITLAB_BASE_URL"], ENV["GITLAB_API_TOKEN"],hooked_jenkins_url
  end

  desc "delete #{repo_name}"
  task "#{next_task_index}_delete" do
    GitlabTools.delete! repo_name, ENV["GITLAB_BASE_URL"], ENV["GITLAB_API_TOKEN"]
  end
end

namespace "git" do
  @task_index = 0

  repo_name=ENV["REPO_NAME"]

  def git_repo_url
    sprintf("%s/%s/%s.git",ENV["GITLAB_BASE_URL"], ENV["GITLAB_USER"], ENV["REPO_NAME"])
  end

  desc "add and commit"
  task "#{next_task_index}_commit", [:msg] do |t, args|
    msg = args.msg || "update"
    sh %Q(git add . && git commit -m "#{msg}")
  end
  
  desc "set remote origin to #{git_repo_url}"
  task "#{next_task_index}_set_remote_orgin" do
    sh %Q(git remote add origin #{git_repo_url})
  end

  desc "reset remote url #{git_repo_url}"
  task "#{next_task_index}_set_remote_url" do
    sh %Q(git remote set-url origin #{git_repo_url})
  end

  desc "push"
  task "#{next_task_index}_push" do
    sh %Q(git push -u origin master)
  end
end
