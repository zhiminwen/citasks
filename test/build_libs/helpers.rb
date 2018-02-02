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
