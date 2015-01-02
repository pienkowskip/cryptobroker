class CreateMarkets < ActiveRecord::Migration
  def change
    create_table :markets do |t|
      t.references :exchange, null: false, index: true
      t.references :base, null: false, index: true
      t.references :quote, null: false, index: true
      t.boolean :traced, null: false
    end
  end
end