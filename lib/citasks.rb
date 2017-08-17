require_relative "citasks/ci_lib"
require_relative "citasks/task_index"

namespace "Jenkins" do
  @task_index = 0
  job_name = ENV["JOB_NAME"]

  def git_repo_url_in_cluster
    sprintf("%s/%s/%s.git",ENV["GITLAB_IN_CLUSTER_BASE_URL"], ENV["GITLAB_USER"], ENV["REPO_NAME"])
  end

  desc "create a new project #{job_name}"
  task "#{next_task_index}_create_new_project" do
    xml_file = job_name + ".xml"
    JenkinsTools.gen_job_xml job_name, xml_file, git_repo_url_in_cluster, ENV["JENKINS_GIT_USER_CREDENTIAL_ID"]

    JenkinsTools.post_new_job job_name, xml_file, ENV["JENKINS_URL"], ENV["JENKINS_USER"], ENV["JENKINS_USER_API_TOKEN"]

    JenkinsTools.gen_jenkins_file
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