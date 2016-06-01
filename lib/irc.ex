defmodule IRCServer do

  def start do
    spawn(fn -> loop end)
  end

  def loop do
    receive do
      {pid, :connect, user} -> IO.puts "SERVER: #{inspect user} conectado!"
      {emisor, receptor, :message, text} ->
      	IO.puts "SERVER: redirecting message to #{inspect receptor}"
      	send receptor, {self, emisor, :leer, text}
      {receptor, emisor, :visto, text} ->
      	IO.puts "SERVER: redirecting visto to #{inspect emisor}"
      	send emisor, {receptor, :visto, text}
      {pid, _ } -> send :pid, {:error, 'Accion Invalida de #{inspect pid}'}
    end
    loop
  end
end

defmodule IRCClient do

  def start do
    spawn(fn -> loop end)
  end

  def loop do
    receive do
      {server, emisor, :leer, text} -> 
      	IO.puts "CLIENT: #{inspect emisor} dice: #{inspect text}"
      	send server, {self, emisor, :visto, text}
      {receptor, :visto, text} -> IO.puts "CLIENT: #{inspect receptor} ha visto el mensaje: #{inspect text}"
      {pid, _ } -> send :pid, {:error, 'Accion Invalida de #{inspect pid}'}
    end
    loop
  end
end
