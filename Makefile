.DEFAULT_GOAL := help

restart: ## copy configs from repository to conf
	@sudo cp config/nginx.conf /etc/nginx/
	@sudo cp config/my.cnf /etc/
	@sudo /usr/sbin/nginx -t
	@make -s nginx-restart
	@make -s db-restart

db-restart: ## Restart mysql
	@sudo service mysqld restart
	@echo 'Restart mysql'

nginx-restart: ## Restart nginx
	@sudo service nginx restart
	@echo 'Restart nginx'

nginx-reset-log: ## reest log and restart nginx
	@sudo rm /var/log/nginx/access.log;sudo service nginx restart

nginx-log: ## tail nginx access.log
	@sudo tail -f /var/log/nginx/access.log

nginx-error-log: ## tail nginx error.log
	@sudo tail -f /var/log/nginx/error.log

myprofiler: ## Run myprofiler
	@myprofiler -user=root

db-slow-query: ## tail slow query log
	@sudo tail -f /var/log/mysql/mysql-slow.log

alp: ## nginx analyzer
	@sudo /usr/local/bin/alp -f /var/log/nginx/access.log  --sum  -r --aggregates '/products/buy/\d+, /products/\d+, /comments/\d+, /users/\d+' --start-time-duration 5m --include-statuses='20[0-9],30[0-2]'
bench: ## Run benchmark
	../benchmark --workload 3

unicorn: # Run Unicorn
	@cd ruby;bundle exec unicorn -c unicorn_config.rb

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
