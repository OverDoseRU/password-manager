require 'base64'
require 'openssl'
require 'digest'

def encrypt(plaintext, password)
  cipher = OpenSSL::Cipher.new('aes-256-gcm')
  cipher.encrypt
  key = OpenSSL::PKCS5.pbkdf2_hmac(password, "salt", 20000, 32, 'sha256')
  cipher.key = key
  iv = cipher.random_iv
  cipher.auth_data = ''
  encrypted = cipher.update(plaintext) + cipher.final
  tag = cipher.auth_tag
  Base64.strict_encode64(iv + tag + encrypted)
end

def decrypt(ciphertext, password)
  data = Base64.decode64(ciphertext)
  iv = data[0..11]
  tag = data[12..27]
  encrypted = data[28..-1]
  decipher = OpenSSL::Cipher.new('aes-256-gcm')
  decipher.decrypt
  key = OpenSSL::PKCS5.pbkdf2_hmac(password, "salt", 20000, 32, 'sha256')
  decipher.key = key
  decipher.iv = iv
  decipher.auth_tag = tag
  decipher.auth_data = ''
  decipher.update(encrypted) + decipher.final
end

def clear_screen
  system("cls") || system("clear")
end

FILE_PATH = File.join(__dir__, "passwords.txt")
HASH_PATH = File.join(__dir__, "master.hash")

print "Введите мастер-пароль: "
master_password = gets.chomp

if File.exist?(HASH_PATH)
  saved_hash = File.read(HASH_PATH).strip
  current_hash = Digest::SHA256.hexdigest(master_password)
  if current_hash != saved_hash
    puts "Неверный мастер-пароль!"
    gets
    exit 1
  end
else
  hash = Digest::SHA256.hexdigest(master_password)
  File.write(HASH_PATH, hash)
  puts "Мастер-пароль установлен. Не потеряйте его!"
  puts "Нажмите Enter..."
  gets
end

loop do
  clear_screen
  puts "Приветствуем вас в программе Менеджера паролей."
  puts "1. Добавить новый пароль"
  puts "2. Посмотреть все пароли"
  puts "3. Найти пароль по сайту"
  puts "0. Выйти"
  print "Выберите действие: "
  
  # Небольшая пауза, чтобы программа не считывала случайные символы
  sleep 0.1
  
  choice = gets.to_s.chomp.strip
  
  # Если выбор пустой или не входит в допустимые варианты — просто перерисовываем меню
  unless ["0", "1", "2", "3"].include?(choice)
    next
  end
  
  break if choice == "0"
  
  case choice
  when "1"
    print "Введите название сайта: "
    website_name = gets.chomp
    print "Введите логин: "
    login = gets.chomp
    print "Введите пароль: "
    pass = gets.chomp
    data = "#{website_name} | #{login} | #{pass}"
    encrypted_data = encrypt(data, master_password)
    File.open(FILE_PATH, "a") do |f|
      f.puts encrypted_data
    end
    puts "Пароль для '#{website_name}' сохранён!"
    puts "Нажмите Enter..."
    gets
    
  when "2"
    if File.exist?(FILE_PATH)
      lines = File.readlines(FILE_PATH)
      if lines.empty?
        puts "Паролей пока нет."
      else
        lines.each do |line|
          begin
            decrypted_line = decrypt(line.chomp, master_password)
            site, login, pass = decrypted_line.split(" | ")
            puts "Сайт: #{site}, Логин: #{login}, Пароль: #{pass}"
          rescue OpenSSL::Cipher::CipherError
            puts "Ошибка: неверный мастер-пароль или файл повреждён"
            puts "Нажмите Enter..."
            gets
            exit 1
          end
        end
      end
    else
      puts "Паролей пока нет."
    end
    puts "Нажмите Enter..."
    gets
    
  when "3"
    print "Введите название сайта: "
    search = gets.chomp
    found = false
    if File.exist?(FILE_PATH)
      File.readlines(FILE_PATH).each do |line|
        begin
          decrypted_line = decrypt(line.chomp, master_password)
          site, login, pass = decrypted_line.split(" | ")
          if site == search
            puts "Сайт: #{site}, Логин: #{login}, Пароль: #{pass}"
            found = true
          end
        rescue OpenSSL::Cipher::CipherError
          puts "Ошибка: неверный мастер-пароль или файл повреждён"
          puts "Нажмите Enter..."
          gets
          exit 1
        end
      end
      puts "Пароль для '#{search}' не найден" unless found
    else
      puts "Паролей пока нет."
    end
    puts "Нажмите Enter..."
    gets
  end
end

puts "До свидания!"