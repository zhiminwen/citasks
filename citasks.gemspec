Gem::Specification.new do |s|
  s.name        = 'citasks'
  s.version     = '0.1.1'
  s.date        = '2017-08-10'
  s.summary     = "ci/cd tools for gitlab + jenkins"
  s.description = "ci/cd tools for gitlab + jenkins. Libray and rake tasks"
  s.authors     = ["Zhimin Wen"]
  s.email       = 'zhimin.wen@gmail.com'
  s.files       = Dir["lib/**/*.rb"] + ["readme.md"]

  s.homepage    = 'http://github.com/zhiminwen/citasks'
  s.license     = 'MIT'

  s.add_dependency 'gitlab', '~> 4.2'

end