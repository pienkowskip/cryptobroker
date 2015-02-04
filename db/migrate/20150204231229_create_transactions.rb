class CreateTransactions < ActiveRecord::Migration
  def change
    reversible do |dir|
      dir.up do
        #add enum type
        execute <<-SQL
          CREATE TYPE transaction_type
            AS ENUM ('buy', 'sell')
        SQL
      end
      dir.down do
        #remove enum type
        execute <<-SQL
          DROP TYPE transaction_type
        SQL
      end
    end

    create_table :transaction do |t|
      t.references :balance, null: false, index: true
      t.column :type, :transaction_type, null: false
      t.decimal :amount, null: false
      t.decimal :price, null: false
    end
  end
end