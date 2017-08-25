module ShellCommandConstructor
  def self.construct_command strings_or_list, connector = " && "
    list = case strings_or_list
    when Array
      strings_or_list
    when String
      strings_or_list.split(/\n/)
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
      fail "Failed to execute #{cmd}"
    end
  end

  def self.test cmd
    system cmd
  end
end
