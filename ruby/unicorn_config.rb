worker_processes 4
preload_app true
pid './unicorn.pid'
# listen '/tmp/unicorn.sock'
listen 8080
# stderr_path './unicorn.log'
# stdout_path './unicorn.log'

after_fork do |m, w| after_fork_foooooo end
