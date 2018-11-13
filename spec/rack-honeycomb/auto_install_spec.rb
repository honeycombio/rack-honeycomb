require "rack-honeycomb/auto_install"

RSpec.describe Rack::Honeycomb::AutoInstall do
  describe "Logging" do
    it "Warning message is logged correctly" do
      logger = double()
      warn_message = "warning"

      Rack::Honeycomb::AutoInstall.instance_variable_set(:@logger, logger)

      expect(logger).to receive(:warn).with(/#{warn_message}/)

      Rack::Honeycomb::AutoInstall.warn(warn_message)
    end
  end
end
