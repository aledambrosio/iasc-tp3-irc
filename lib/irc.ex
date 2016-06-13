defmodule Client do
  defstruct username: "", pid: nil, mutedList: []
end

defmodule IRCServer do

  def addMute(emisorList, receptor) do
    #List.flatten(Map.get(emisorList,:mutedList),[receptor])
    List.insert_at(emisorList, -1, receptor)
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
      Map.get(x,:pid) != client
    end    
  end

  def getEmisor(emisores, emisor) do
    IO.puts "emisores: #{inspect emisores} / emisor: #{inspect emisor}"
    Enum.find emisores, fn x ->
      Map.get(x,:pid) == emisor
    end
  end

  def getMuted(client) do
    Map.get(client,:mutedList)
  end

  def start(emisores) do
    spawn(fn -> loop(emisores) end)
  end

  def loop(emisores) do
    receive do
      {pid, :connect, user} ->
      	client = %Client{pid: pid, username: user, mutedList: []}
      	IO.puts "SERVER: Se conectó: #{inspect client.pid} #{inspect client.username} #{inspect client.mutedList}"
      	List.insert_at List.wrap(emisores), -1, client
      	IO.puts "Al conectar cliente: emisores #{inspect emisores}"
      	loop(emisores)
      {emisor, receptor, :message, text} ->
      	IO.puts "SERVER: redirecting message to #{inspect receptor}"
      	send receptor, {self, emisor, :leer, text}
      	loop(emisores)
      {receptor, emisor, :visto, text} -> 
      	emisorClient = getEmisor(emisores, emisor)
        if (!isMuted(emisorClient, receptor)) do
	    	IO.puts "SERVER: redirecting visto to #{inspect emisor}"
	    	send emisor, {receptor, :visto, text}
        end
      	loop(emisores)
      {emisor, receptor, :escribe} ->
      	send receptor, {emisor, :escribe}
      	loop(emisores)
      {receptor, emisor, :silenciar} -> 
      	emisorClient = getEmisor(emisores, emisor)
		emisorList = filterClient(emisores, emisor)

      	IO.puts "emisorClient: #{inspect emisorClient}"
      	addMute(List.wrap(emisorList), receptor)

        loop(emisores) 
	  {pid, _ } -> 
	  	send pid, {:error, 'Accion Invalida de #{inspect pid}'}
       	loop(emisores)
    end
    loop(emisores)
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
