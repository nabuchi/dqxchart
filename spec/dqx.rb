#!/usr/bin/env ruby
# encoding: utf-8
require 'capybara'
require 'capybara-webkit'
require 'capybara/rspec'
require 'headless'
require 'mongo'
require 'yaml'

Capybara.app = "DQX crawler"
Capybara.default_driver = :webkit
Capybara.javascript_driver = :webkit
Capybara.run_server = false

DB_NAME = 'dqxchart'
ITEM_MASTER       = 'item_master'
AMT_DATA          = 'amt_data'

auth_file = YAML.load_file(File.join(ENV['HOME'], '.ssh/dq.yml'))
USER = auth_file['user']
PASS = auth_file['pass']

describe "dqx hiroba access", :type => :feature do
    before :all do
        visit("http://hiroba.dqx.jp/sc/")
        find("#btn_login").click
        find("#sqexid").set(USER)
        find("#passwd").set(PASS)
        find("#btLogin").click
        find("#welcome_box").find("a").click
        first("td.btn_cselect").find("a").click
        #save_and_open_page
        #p page.html
    end

    before :all do
        @con = Mongo::Connection.new
        @db = @con.db(DB_NAME)
    end
    it "get amt" do
        item_master = @db.collection(ITEM_MASTER)
        amt_data = @db.collection(AMT_DATA)
        item_master.find.each do |data|
            web_id = data['web_id']
            if web_id.nil? || web_id.empty?
                visit("http://hiroba.dqx.jp/sc/search/#{data['name']}")
                web_id = page.evaluate_script('$(".searchItemTable a:eq(1)").attr("href").match(/([\d\w]+)\/$/)[1]');
            end
            visit("http://hiroba.dqx.jp/sc/search/bazaar/#{web_id}/")
            error_str = page.evaluate_script('$(".error_red").text()');
            if error_str == 'エラー'
                visit("http://hiroba.dqx.jp/sc/search/#{data['name']}")
                web_id = page.evaluate_script('$(".searchItemTable a:eq(1)").attr("href").match(/([\d\w]+)\/$/)[1]');
                visit("http://hiroba.dqx.jp/sc/search/bazaar/#{web_id}/")
            end
            result = page.evaluate_script('var ret = []; $("table.bazaarTable tr").each(function(){var amt = $(this).find("td:eq(1) p:eq(1)").text(); var place = $(this).find("td:eq(2)").text();var num=$(this).find("td:eq(1) p:eq(0)").text(); if(amt && place && num){amt = amt.match(/([\d,]+)G/); num = num.match(/(\d+)/); ret.push(amt[1].replace(/,/g,"") + "," + place.replace(/\s+/g, "") + "," + num[1]) }}); ret');
            #amt = result[5].split(",")[0]
            amt = result.map{|r| r.split(",")[0].to_i/r.split(",")[2].to_f}
            rec = {'id'   => data['id'],
                   'name' => data['name'],
                   'amt'  => amt,
                   'register_date' => Time.now
                  }
            amt_data.insert(rec)
            if web_id != data['web_id']
                item_master.update({:id => data['id']}, '$set' => {:web_id => web_id, :amt => amt})
            end
            item_master.update({:id => data['id']}, '$set' => {:amt => amt})
            sleep 3
        end
    end
end
