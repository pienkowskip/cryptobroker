class CreateTrades < ActiveRecord::Migration
  def change
    create_table :trades do |t|
      t.references :market, null: false, index: true
      t.decimal :amount, null: false
      t.decimal :price, null: false
      t.timestamp :timestamp, null: false
      t.integer :tid
    end
  end
end