class CreateCurrencies < ActiveRecord::Migration
  def change
    create_table :currencies do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :crypto, null: false
    end
    add_index :currencies, :name, unique: true
  end
end