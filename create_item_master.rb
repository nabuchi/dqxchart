#!/usr/bin/env ruby
# encoding: utf-8
require 'rspec'
require 'mongo'
require 'digest/hmac'
require 'yaml'
require 'uri'

DB_NAME = 'dqxchart'
ITEM_MASTER       = 'item_master'
KEY = 'daiki.a.nabuchi'

class CreateItemMaster
    def initialize
        @con = Mongo::Connection.new
        @db = @con.db(DB_NAME)
    end

    def create
        col = @db.collection(ITEM_MASTER)
        ids = []
        col.find().each do |rec|
            ids << rec["id"]
        end
        add_item = YAML.load(open("conf/add_item.yml"))
        add_item.each do |item_name|
            name = URI.escape(item_name)
            id = Digest::HMAC.hexdigest(name, KEY, Digest::SHA1)[0..9]
            next if ids.include?(id)
            rec = {:name => name,
                   :id   => id,
                   :amt   => {},
                   :web_id=> '',
            }

            col.insert(rec)
        end
    end

    def update
        col = @db.collection(ITEM_MASTER)

    end
end

cim = CreateItemMaster.new
cim.create

