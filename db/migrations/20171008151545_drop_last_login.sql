
-- +goose Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE `users` DROP `last_login`;


-- +goose Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE `users` ADD `last_login` datetime;
