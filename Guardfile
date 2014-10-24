# -*- ruby -*-
guard :shell do
  interactor   :off
  notification  :emacs
  watch(/^(lib|test).*\.exs?$/) do |f|
    `mix test >/dev/tty`
    if $?.success?
      Notifier.notify "Success", type: "success"
    else
      Notifier.notify "Failed", type: "failed"
    end
  end
end
