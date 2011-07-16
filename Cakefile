{ exec, spawn } = require 'child_process'
print = (data) -> console.log data.toString().trim()

task 'build', ->
  exec 'mkdir -p lib && coffee -c -o lib src'

task 'dev', 'Continuous compilation', ->
  coffee = spawn 'coffee', '-wc --bare -o lib src'.split(' ')
  coffee.stdout.on 'data', print
  coffee.stderr.on 'data', print

task 'test', ->
  exec 'vows test/*.coffee', (error, stdout, stderr) ->
    print stdout
    print stderr