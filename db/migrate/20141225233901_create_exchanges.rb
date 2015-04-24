class CreateExchanges < ActiveRecord::Migration
  def change
    create_table :exchanges do |t|
      t.string :name, null: false
      t.string :api_class, null: false
    end
    add_index :exchanges, :name, unique: true
  end
end