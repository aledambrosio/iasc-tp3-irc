defmodule Client do
  defstruct username: "", pid: nil, mutedList: []
end

 
defmodule IRCServer do

  def addMute(usuarios, receptor) do
    IO.puts "addMute: usuarios #{inspect usuarios}"
    List.flatten(usuarios,[receptor])
#    List.flatten(Map.get(usuarios,:mutedList),[receptor])
  end

  def isMuted(emisorClient, emisor) do
  	if emisorClient != nil do
    	mutedList = Map.get(emisorClient, :mutedList)
    	if (Enum.member?(mutedList, emisor)) do          
      	true
    	else
      	false
    	end    
    else
    	false
	  end
  end

  def filterClient(clients, client) do
    Enum.filter clients, fn x ->
      Map.get(x,:pid) != client.pid
    end    
  end

  def getEmisor(usuarios, emisor) do
    IO.puts "usuarios: #{inspect usuarios} / emisor: #{inspect emisor}"
    Enum.find usuarios, fn x ->
      Map.get(x,:pid) == emisor
    end
  end

  def getMuted(client) do
    Map.get(client,:mutedList)
  end

  def start(usuarios) do
    spawn(fn -> loop(usuarios) end)
  end

  def loop(usuarios) do
    receive do
      {pid, :connect, user} ->
      	client = %Client{pid: pid, username: user, mutedList: []}
      	IO.puts "SERVER: Se conectó: #{inspect client.pid} #{inspect client.username} #{inspect client.mutedList}"
        loop([client|usuarios])
      {emisor, receptor, :message, text} ->
      	IO.puts "SERVER: redirecting message to #{inspect receptor}"
      	send receptor, {self, emisor, :leer, text}
      {receptor, emisor, :visto, text} -> 
      	emisorClient = getEmisor(usuarios, emisor)
        if (!isMuted(emisorClient, receptor)) do
	    	  IO.puts "SERVER: not muted, redirecting visto to #{inspect emisor}"
	    	  send emisor, {receptor, :visto, text}
        end
      {emisor, receptor, :escribe} ->
      	send receptor, {emisor, :escribe}
      {receptor, emisor, :silenciar} -> 
      	emisorClient = getEmisor(usuarios, emisor)
        IO.puts "emisorClient: #{inspect emisorClient}"
#		    mutedList = filterClient(usuarios, emisor)
        IO.puts "mutedList: #{inspect emisorClient.mutedList}"
      	addMute(emisorClient.mutedList, receptor)
        loop(usuarios)
	  {pid, _ } -> 
	  	send pid, {:error, 'Accion Invalida de #{inspect pid}'}
    end
    loop(usuarios)
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
      	loop
      {receptor, :visto, text} ->
      	IO.puts "CLIENT: #{inspect receptor} ha visto el mensaje: #{inspect text}"
      	loop
      {emisor, :escribe} ->
      	IO.puts "CLIENT: #{inspect emisor} está escribiendo..."
      	loop
      {pid, _ } ->
      	send :pid, {:error, 'Accion Invalida de #{inspect pid}'}
      	loop
    end
    loop
  end
end
