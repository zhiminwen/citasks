@task_index=0
def next_task_index
  @task_index += 1
  sprintf("%02d", @task_index)
end
