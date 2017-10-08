require 'sinatra/base'
require 'mysql2'
require 'mysql2-cs-bind'
require 'rack-mini-profiler'
require 'rack-lineprof'
require 'erubis'
require 'rack/session/dalli'

def config
  @config ||= {
    db: {
      host: ENV['ISHOCON1_DB_HOST'] || 'localhost',
      port: ENV['ISHOCON1_DB_PORT'] && ENV['ISHOCON1_DB_PORT'].to_i,
      username: ENV['ISHOCON1_DB_USER'] || 'root',
      password: ENV['ISHOCON1_DB_PASSWORD'] || '',
      database: ENV['ISHOCON1_DB_NAME'] || 'ishocon1'
    }
  }
end

def db
  return Thread.current[:ishocon1_db] if Thread.current[:ishocon1_db]
  client = Mysql2::Client.new(
    host: config[:db][:host],
    port: config[:db][:port],
    username: config[:db][:username],
    password: config[:db][:password],
    database: config[:db][:database],
    reconnect: true
  )
  client.query_options.merge!(symbolize_keys: true)
  Thread.current[:ishocon1_db] = client
  client
end

def load_upcomming_comments
  $loaded_comment_id ||= 0
  $product_comments ||= {}
  # last_id = db.query('select id from comments order by id desc limit 1').first[:id]
  # if last_id < $loaded_comment_id
  #   $loaded_comment_id = 0
  #   $product_comments = {}
  # end
  db.xquery('SELECT SQL_NO_CACHE * from comments where id > ? order by created_at asc, id asc', $loaded_comment_id).to_a.each do |comment|
    ($product_comments[comment[:product_id]] ||= []).unshift comment
    $loaded_comment_id = comment[:id] if comment[:id] > $loaded_comment_id
  end
end

def _find_all_user
  $id_users = []
  $email_users = {}
  db.xquery('SELECT SQL_NO_CACHE * from users').to_a.each do |user|
    $id_users[user[:id]] = user
    $email_users[user[:email]] = user
  end
end


def _load_all_products
  $products = []
  db.xquery('SELECT SQL_NO_CACHE * from products').to_a.each do |product|
    $products[product[:id]] = product
  end
  $products
end
_load_all_products
def find_product id
  $products[id.to_i]
end

def product_list(offset, limit)
  limit.times.map do |i|
    idx = $products.size - offset - i - 1
    $products[idx] if idx >= 0
  end.compact
end

load_upcomming_comments
_find_all_user


module Ishocon1
  class AuthenticationError < StandardError; end
  class PermissionDenied < StandardError; end
end

class Ishocon1::WebApp < Sinatra::Base
  session_secret = ENV['ISHOCON1_SESSION_SECRET'] || 'showwin_happy'

  use Rack::Lineprof if ENV['DEBUG']
  use Rack::MiniProfiler if ENV['DEBUG']
  use Rack::Session::Dalli, cache: Dalli::Client.new, namespace: session_secret
  set :erb, escape_html: true
  set :public_folder, File.expand_path('../public', __FILE__)
  set :protection, true

  helpers do
    def find_user(id)
      _find_all_user unless $id_users
      $id_users[id.to_i] if id
    end

    def find_user_by_email(email)
      _find_all_user unless $email_users
      $email_users[email] if email
    end


    def comments_by_product_id product_id
      $product_comments[product_id] || []
    end

    def time_now_db
      Time.now - 9 * 60 * 60
    end

    def authenticate(email, password)
      user = find_user_by_email(email)
      fail Ishocon1::AuthenticationError unless user[:password] == password
      session[:user_id] = user[:id]
    end

    def authenticated!
      fail Ishocon1::PermissionDenied unless current_user
    end

    def current_user
      @user ||= find_user(session[:user_id])
    end

    def update_last_login(user_id)
      db.xquery('UPDATE users SET last_login = ? WHERE id = ?', time_now_db, user_id)
    end

    def buy_product(product_id, user_id)
      db.xquery('INSERT INTO histories (product_id, user_id, created_at) VALUES (?, ?, ?)', \
        product_id, user_id, time_now_db)
    end

    def already_bought?(product_id)
      return false unless current_user
      count = db.xquery('SELECT count(*) as count FROM histories WHERE product_id = ? AND user_id = ?', \
                        product_id, current_user[:id]).first[:count]
      count > 0
    end

    def create_comment(product_id, user_id, content)
      db.xquery('INSERT INTO comments (product_id, user_id, content, created_at) VALUES (?, ?, ?, ?)', \
        product_id, user_id, content, time_now_db)
    end
  end

  error Ishocon1::AuthenticationError do
    session[:user_id] = nil
    halt 401, erb(:login, layout: false, locals: { message: 'ログインに失敗しました' })
  end

  error Ishocon1::PermissionDenied do
    halt 403, erb(:login, layout: false, locals: { message: '先にログインをしてください' })
  end

  get '/login' do
    session.clear
    erb :login, layout: false, locals: { message: 'ECサイトで爆買いしよう！！！！' }
  end

  post '/login' do
    authenticate(params['email'], params['password'])
    # update_last_login(current_user[:id])
    redirect '/'
  end

  get '/logout' do
    session[:user_id] = nil
    session.clear
    redirect '/login'
  end

  get '/' do
    page = params[:page].to_i || 0
    products = product_list page * 50, 50
    load_upcomming_comments
    erb :index, locals: { products: products }
  end

  get '/users/:user_id' do
    histories = db.xquery('select product_id, user_id from histories where user_id = ? order by id desc', params[:user_id])

    total_pay = 0
    histories.each do |history|
      total_pay += find_product(history[:product_id])[:price]
    end

    user = find_user params[:user_id]
    erb :mypage, locals: { histories: histories, user: user, total_pay: total_pay }
  end

  get '/products/:product_id' do
    product = find_product params[:product_id]
    erb :product, locals: { product: product }
  end

  post '/products/buy/:product_id' do
    authenticated!
    buy_product(params[:product_id], current_user[:id])
    redirect "/users/#{current_user[:id]}"
  end

  post '/comments/:product_id' do
    authenticated!
    create_comment(params[:product_id], current_user[:id], params[:content])
    redirect "/users/#{current_user[:id]}"
  end

  get '/initialize' do
    40.times do
      `curl http://localhost:8080/true_initialize`
    end
    "Finish"
  end

  get '/true_initialize' do
    $loaded_comment_id = 0
    $product_comments = {}
    db.query('DELETE FROM users WHERE id > 5000')
    db.query('DELETE FROM products WHERE id > 10000')
    db.query('DELETE FROM comments WHERE id > 200000')
    db.query('DELETE FROM histories WHERE id > 500000')
    "Finish"
  end
end
