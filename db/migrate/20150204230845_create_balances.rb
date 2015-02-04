class CreateBalances < ActiveRecord::Migration
  def change
    create_table :balances do |t|
      t.references :investor, null: false, index: true
      t.decimal :base, null: false
      t.decimal :quote, null: false
      t.timestamp :timestamp, null: false
    end
  end
end