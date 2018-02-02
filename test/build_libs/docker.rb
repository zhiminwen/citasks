require_relative "shell"

module DockerTools
  def self.add_etc_hosts
    etc_hosts_entry = sprintf("%s %s", ENV["PRIVATE_DOCKER_REGISTRY_IP"], ENV["PRIVATE_DOCKER_REGISTRY_NAME"])
    Shell.run %Q(echo "#{etc_hosts_entry}" >> /etc/hosts)
  end

  def self.push_to_registry image_name, tag
    private_registry = sprintf("%s:%s", ENV["PRIVATE_DOCKER_REGISTRY_NAME"], ENV["PRIVATE_DOCKER_REGISTRY_PORT"])
    namespace = ENV["PRIVATE_DOCKER_REGISTRY_NAMESPACE"]

    cmds = ShellCommandConstructor.construct_command %Q{
      docker login -u #{ENV["PRIVATE_DOCKER_REGISTRY_USER"]} -p #{ENV["PRIVATE_DOCKER_REGISTRY_USER_PASSWORD"]} #{private_registry}

      docker tag #{image_name}:#{tag} #{private_registry}/#{namespace}/#{image_name}:#{tag}
      docker push #{private_registry}/#{namespace}/#{image_name}:#{tag}
    }
    Shell.run cmds
  end
end
