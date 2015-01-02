class CreateExchanges < ActiveRecord::Migration
  def change
    create_table :exchanges do |t|
      t.string :name, null: false
      t.string :api, null: false
    end
  end
end