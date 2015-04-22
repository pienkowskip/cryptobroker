class CreateVariables < ActiveRecord::Migration
  def change
    create_table :variables do |t|
      t.references :investor, null: false, index: true
      t.string :name, null: false
      t.binary :value
    end
    add_index :variables, [:name, :investor_id], unique: true
  end
end