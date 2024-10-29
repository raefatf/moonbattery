class Battery < ApplicationRecord
  validates :mac_address, presence: true, uniqueness: true, format: { 
    with: /\A([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2}\z/,
    message: "must be in the format XX:XX:XX:XX:XX:XX" 
  }
end
