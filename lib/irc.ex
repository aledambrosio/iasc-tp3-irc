defmodule Client do
  defstruct username: "", pid: nil, mutedList: []
end

 
defmodule IRCServer do

  def isMuted(client, element) do
    muted = Map.get(client, :mutedList)
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
      	IO.puts "SERVER: New connection: #{inspect client.pid} #{inspect client.username} #{inspect client.mutedList}"
        loop([client|usuarios])
      {emisor, receptor, :message, text} ->
        receptorUser = getUsuario(usuarios, receptor)
        if (!isMuted(receptorUser, emisor)) do
          send receptor, {self, emisor, :leer, text}
        else
          IO.puts "SERVER-':leer' Usuario #{inspect emisor} fue silenciado por #{inspect receptor}"
        end
        loop(usuarios)
      {lector, emisor, :visto, text} -> 
      	emisorUser = getUsuario(usuarios, emisor)
        if (!isMuted(emisorUser, lector)) do
	    	  send emisor, {lector, :visto, text}
        else
          IO.puts "SERVER-':visto' Usuario #{inspect lector} fue silenciado por #{inspect emisor}"
        end
        loop(usuarios)
      {emisor, receptor, :escribiendo} ->
        receptorUser = getUsuario(usuarios, receptor)
        if (!isMuted(receptorUser, emisor)) do
          send receptor, {emisor, :escribiendo}
        else
          IO.puts "SERVER-':escribiendo' Usuario #{inspect receptor} fue silenciado por #{inspect emisor}"
        end
      {lector, emisor, :silenciar} -> 
        usuario = getUsuario(usuarios, lector)
        restantes = filter(usuarios, lector)
        usuarios = List.insert_at(restantes, -1, 
                                updateMute(usuario, 
                                addMute(usuario, emisor)))
        IO.puts "SERVER-':silenciar' Usuario #{inspect emisor} silenciado por #{inspect lector}"
        loop(usuarios)
	  {pid, _ } -> 
	  	send pid, {:error, 'Invalid action from #{inspect pid}'}
    end
    loop(usuarios)
  end
end

defmodule IRCClient do

  def start do
    spawn(fn -> loop(self) end)
  end

  def loop(server) do
    receive do
      {serverPid, :connect, username} -> 
        send serverPid, {self, :connect, username}
        loop(serverPid)
      {serverPid, emisor, :leer, text} -> 
      	IO.puts "CLIENT: #{inspect emisor} dice: #{inspect text}"
      	send serverPid, {self, emisor, :visto, text}
      	loop(server)
      {receptor, :visto, text} ->
      	IO.puts "CLIENT: #{inspect receptor} ha visto el mensaje: #{inspect text}"
      	loop(server)
      {emisor, :escribiendo} ->
      	IO.puts "CLIENT: #{inspect emisor} está escribiendo..."
      	loop(server)
      {receptor, :escribir, texto} ->
        send server, {self, receptor, :escribiendo}
        :timer.sleep(3* 1000)
        send server, {self, receptor, :message, texto}
        loop(server)
      {usuario, :silenciar} -> 
        send server, {self, usuario, :silenciar}
        loop(server)
      {pid, _ } ->
      	send :pid, {:error, 'Accion Inválida de #{inspect pid}'}
      	loop(server)
    end
    loop(server)
  end
end
