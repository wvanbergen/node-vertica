{ exec, spawn } = require 'child_process'
print = (data) -> console.log data.toString().trim()

task 'build', ->
  exec 'mkdir -p lib && coffee -c -o lib src'

task 'clean', ->
  exec 'rm -rf lib'

task 'dev', 'Continuous compilation', ->
  coffee = spawn 'coffee', '-wc --bare -o lib src'.split(' ')
  coffee.stdout.on 'data', print
  coffee.stderr.on 'data', print

task 'test', ->
  exec 'vows test/*.coffee', (error, stdout, stderr) ->
    print stdout
    print stderr

task 'tag', ->
  throw "Please do not run this task directly, use npm publish instead." unless process.env.npm_package_name? && process.env.npm_package_version?
  exec "git tag -m 'Tagged #{process.env.npm_package_name} version #{process.env.npm_package_version}.' '#{process.env.npm_package_name}-#{process.env.npm_package_version}'" 

task 'push', ->
  exec "git push --tags"