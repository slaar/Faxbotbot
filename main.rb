require 'rubygems'
require 'watir'
require 'watir-webdriver'

info_file = "info.txt"

=begin

info.txt is a text file with 5 lines
the lines are, in order, with no embellishment or extra whitespace:

account name      (name of your meta-bot)
password          (password to your meta-bot)
full clan name    (if you are in guild PVP JERKS then this line would read "PVP JERKS")
clan short name   (if your guild was PVP JERKS you might whitelist into it with /whitelist PVP so this line would be "PVP")
fax short name    (if your open fax is in "DUMB BUNNIES" clan then you would /whitelist DUMB so this line might be "DUMB")

=end

vars = File.readlines(info_file)
#vars.each do |v| puts v.strip + ": " + v.strip.length.to_s end

$account_name = vars[0].strip
$account_password = vars[1].strip
$clan_full_name = vars[2].strip
$clan_short_name = vars[3].strip
$fax_clan_short_name = vars[4].strip

$chatbrowser = Watir::Browser.new

$chatbrowser.goto 'http://kingdomofloathing.com/game.php'

$chatbrowser.text_field(:name => "loginname").set($account_name)
$chatbrowser.text_field(:name => "password").set($account_password)

if $chatbrowser.button(:value, "Log In").exists? then
  $chatbrowser.button(:value, "Log In").click
end

$chat = $chatbrowser.frame(:name, "chatpane")
$menu = $chatbrowser.frame(:name, "menupane")
$main = $chatbrowser.frame(:name, "mainpane")
$chat.link(:text, /Enter the Chat/).click

$queue = Array.new
$busy = false

$easyfax = false
$faustbot = false
$faxbot = false

def RefreshQueue()
  input = $chat.div(:id => "ChatWindow").text
  if input.length > 0 then
    words = input.scan(/.+\(private\).+/)
    ChatCommand("/clear")
    if words.any? then
      $queue << words.flatten
      $queue.each{|mob| puts mob}
      if !$queue.empty? then
        ProcessQueue() unless $busy
      end
    end
  end
end

def ChatCommand(c)
  $chat.text_field(:name, "graf").set(c)
  $chat.button(:value, "Chat").click
  puts "CC: " + c unless c == "/clear"
end

def ProcessQueue()
  line = $queue.shift.first
  user = line.scan(/(.+) \(/).last.first
  if user.downcase == "faxbot" or user.downcase == "easyfax" or user.downcase == "faustbot" then
  return
  else
    ChatCommand("/whois " + user)
    sleep(2)
    $chat.link(:text => /#{user}/).click
    sleep(2)
    valid_clan = false
    clan = ""
    $main.links.each{
    |l|
      if l.href.scan(/(showclan)/).any? then
        puts l.text
      end
      if l.text.strip == $clan_full_name then
      valid_clan=true
      end
    }
    if !valid_clan then
      ChatCommand("/msg " + user.downcase.tr(" ","_") + " UNAUTHORIZED ACCESS")
      $busy = false
    return
    end
  end
  bot = ""
  mob = ""
  if line.scan(/: (.+) /).any? then
    bot = line.scan(/: ([^ ]+) /).last.first
    if line.scan(/#{bot} (.+)$/).any? then
      mob = line.scan(/#{bot} (.+)$/).last.first
    end
  end
  if bot.length > 0 and mob.length > 0 then
    puts user + " wants a " + mob + " from " + bot
    ChatCommand("/msg " + user.downcase.tr(" ","_") + " You have requested '" + mob + "' from " + bot + "!")
  else
    ChatCommand("/msg " + user.downcase.tr(" ","_") + " Command requires [botname] [monster name].")
  end
  if bot.downcase == "easyfax" or bot.downcase == "faxbot" or bot.downcase == "faustbot" then
    $busy = true
    RequestFax(user,bot,mob)
  else
    ChatCommand("/msg " + user.downcase.tr(" ","_") + " I do not recognize this bot: " + bot + "!")
  end
end

def RequestFax(user,bot,mob)
  ChatCommand("/friends")
  sleep(5)
  input = $chat.div(:id => "ChatWindow").table.td(:class => "tiny")
  puts input.text
  if input.text.length > 0 then
    words = input.html.scan(/.+showplayer.+/)
    list = words.flatten
    list.each{
    |poss|
      if poss.include? "2194132" then
        $faxbot = true
        puts "Faxbot Found"
      end
      if poss.include? "2504737" then
        $easyfax = true
        puts "Easyfax found"
      end
      if poss.include? "2504770" then
        $faustbot = true
        puts "Faustbot found"
      end
    }
  end
  if (bot == "faxbot" and $faxbot) or (bot == "easyfax" and $easyfax) or (bot == "faustbot" and $faustbot) then
    ChatCommand("/whitelist " + $fax_clan_short_name)
    ChatCommand("/msg " + bot + " " + mob)
    fax_complete = false
    attempts = 0
    while !fax_complete and attempts <= 3 do
      attempts = attempts + 1
      sleep(15)
      input = $chat.div(:id => "ChatWindow").text
      if input.length > 0 then
        words = input.scan(/.+\(private\).+/)
        ChatCommand("/clear")
        if words.any? then
          puts "Robo-Response: " + words.last
          responding_bot = words.last.scan(/(.+) \(/).last.first
          if responding_bot.downcase == "faxbot" or responding_bot.downcase == "easyfax" or responding_bot.downcase == "faustbot" then
            if words.last.include? "has copied" or words.last.include? "fax is ready" or words.last.include? "has been delivered" then
              fax_complete = true
              CompleteFax(user,mob,bot)
            break
            else
              puts "Robot error: " + words.last
              if words.last.include? "do not understand" or words.last.include? "find that monster" or words.last.include? "an invalid monster" then
                ChatCommand("/msg " + user.downcase.tr(" ","_") + " Hey, " + bot + " doesn't know that mob by that name (" + mob + ").")
              $busy = false
              return
              end
              if words.last.include? "just delivered" or words.last.include? "made a request" then
                ChatCommand("/msg " + user.downcase.tr(" ","_") + " Hey, " + bot + " requests that you wait a bit, sorry.")
              $busy = false
              return
              end
            end
          end
        end
      end
    end
    if !fax_complete then
      ChatCommand("/msg " + user.downcase.tr(" ","_") + " Hey, " + bot + " didn't respond after 30 seconds so...")
    $busy = false
    return
    end
  else
    ChatCommand("/msg " + user.downcase.tr(" ","_").downcase.tr(" ","_") + " I didn't see " + bot + " online!")
  $busy = false
  end
end

def CompleteFax(user,mob,bot)

  ChatCommand("/go vip")
  sleep(1)
  $main.image(:title => "A Fax Machine").click
  sleep(1)
  $main.button(:value => "Receive a Fax").click
  sleep(1)
  ChatCommand("/whitelist " + $clan_short_name)
  $main.image(:title => "A Fax Machine").click
  sleep(1)
  $main.button(:value => "Send a Fax").click
  ChatCommand("/msg " + user.downcase.tr(" ","_") + " One "+mob+" in Fax courtesy of " +bot+ ".")
  $busy = false

end

while true do
  unless $busy
    sleep(5)
    RefreshQueue()
  end
end
