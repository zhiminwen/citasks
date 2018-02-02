require "erb"
require_relative "shell"

module KubeTools
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

  def self.deploy_to_k8s namespace, deployment, yaml_file, image_name, new_image_name
    Shell.run %Q(kubectl apply -f #{yaml_file})
  end
end
