
-- +goose Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE `comments` ADD INDEX (`product_id`);
ALTER TABLE `comments` ADD INDEX (`user_id`);
ALTER TABLE `histories` ADD INDEX (`product_id`);
ALTER TABLE `histories` ADD INDEX (`user_id`);
ALTER TABLE `users` ADD INDEX (`email`);

-- +goose Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE `comments` DROP INDEX `product_id`;
ALTER TABLE `comments` DROP INDEX `user_id`;
ALTER TABLE `histories` DROP INDEX `product_id`;
ALTER TABLE `histories` DROP INDEX `user_id`;
ALTER TABLE `users` DROP INDEX `email`;
