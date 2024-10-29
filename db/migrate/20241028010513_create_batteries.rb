class CreateBatteries < ActiveRecord::Migration[8.0]
  def change
    create_table :batteries do |t|
      t.string :mac_address, null: false, unique: true
      t.string :serial_number, null: false, unique: true
      t.datetime :last_contact
      t.integer :lock_update, default: 0
      t.json :configurations, default: {}

      t.timestamps
    end
  end
end
