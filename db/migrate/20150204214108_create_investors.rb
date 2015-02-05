class CreateInvestors < ActiveRecord::Migration
  def change
    create_table :investors do |t|
      t.references :market, null: false, index: true
      t.string :name, null: false
      t.timestamp :beginning, null: false
      t.integer :timeframe, null: false
      t.string :indicator_class, null: false
      t.string :indicator_conf
      t.string :broker_class, null: false
      t.string :broker_conf
    end
  end
end