require 'dotenv'
Dotenv.load ".env.build"
require_relative "build_libs/helpers"

image_name = ENV["IMAGE_NAME"]
tag=ENV["BUILD_NUMBER"]||"B1"

namespace "docker" do
  rest_task_index

  desc "build docker image"
  task "#{next_task_index}_build_image" do
    sh %Q(docker build -t #{image_name}:#{tag} .)
  end

  desc "push to ICp registry"
  task "#{next_task_index}_push_to_ICp_registry" do
    DockerTools.add_etc_hosts
    DockerTools.push_to_registry image_name, tag_name
  end
end

namespace "k8s" do
  rest_task_index

  desc "deploy into k8s"
  task "#{next_task_index}_deploy_to_k8s" do
    yaml_template_file = "#{image_name}.k8.template.yaml"
    yaml_file = "#{image_name}.yaml"

    private_registry = sprintf("%s:%s", ENV["PRIVATE_DOCKER_REGISTRY_NAME"], ENV["PRIVATE_DOCKER_REGISTRY_PORT"])
    namespace = ENV["PRIVATE_DOCKER_REGISTRY_NAMESPACE"]
    full_new_image_name = "#{private_registry}/#{namespace}/#{image_name}:#{tag}"
    data = {
      new_image: full_new_image_name
    }

    KubeTools.create_new_yaml yaml_template_file, yaml_file, data

    deployment = image_name
    KubeTools.deploy_to_k8s deployment, yaml_file, image_name, full_new_image_name

  end
end    
