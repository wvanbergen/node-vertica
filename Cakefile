{ exec, spawn } = require 'child_process'
print = (data) -> console.log data.toString().trim()

task 'build', ->
  exec 'mkdir -p lib && coffee --bare -c -o lib src'

task 'clean', ->
  exec 'rm -rf lib'

task 'dev', 'Continuous compilation', ->
  coffee = spawn 'coffee', '-wc --bare -o lib src'.split(' ')
  coffee.stdout.on 'data', print
  coffee.stderr.on 'data', print
