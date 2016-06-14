defmodule Client do
  defstruct username: "", pid: nil, mutedList: []
end

 
defmodule IRCServer do

  def isMuted(client, element) do
    muted = Map.get(client, :mutedList)
    IO.puts "Muted: #{inspect muted}"
    if (Enum.member?(muted, element)) do          
      true
    else
      false
    end    
  end

  def filter(users, clientPid) do
    Enum.filter users, fn x ->
      Map.get(x,:pid) != clientPid
    end    
  end

  def addMute(client, element) do
    List.flatten(Map.get(client,:mutedList),[element])
  end

  def removeMute(client, element) do
    List.delete(Map.get(client, :mutedList), element)
  end

  def updateMute(client, new_muted) do
    Map.put(client, :mutedList, new_muted)
  end

  def getUsuario(usuarios, pid) do
    Enum.find usuarios, fn x ->
      Map.get(x,:pid) == pid
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
        loop(usuarios)
      {receptor, emisor, :visto, text} -> 
      	emisorClient = getUsuario(usuarios, emisor)
        if (!isMuted(emisorClient, receptor)) do
	    	  IO.puts "SERVER: not muted, redirecting visto to #{inspect emisor}"
	    	  send emisor, {receptor, :visto, text}
        end
        loop(usuarios)
      {emisor, receptor, :escribe} ->
      	send receptor, {emisor, :escribe}
      {emisor, receptor, :silenciar} -> 
        usuario = getUsuario(usuarios, emisor)
        rest_list = filter(usuarios, emisor)
        usuarios = List.insert_at(rest_list, -1, 
                                updateMute(usuario, 
                                addMute(usuario, receptor)))
        IO.puts "Usuarios #{inspect usuarios}"
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
