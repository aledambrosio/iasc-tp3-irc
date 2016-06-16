defmodule Client do
  defstruct username: "", pid: nil, mutedList: []
end

 
defmodule IRCServer do

  def isMuted(client, element) do
#    IO.puts "isMuted? client #{inspect client}"
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
#    IO.puts "SERVER: Usuarios: #{inspect usuarios}"
    receive do
      {pid, :connect, user} ->
      	client = %Client{pid: pid, username: user, mutedList: []}
#      	IO.puts "SERVER: New connection: #{inspect client.pid} #{inspect client.username} #{inspect client.mutedList}"
        loop([client|usuarios])
      {emisor, :message, text} ->
#        IO.puts "SERVER: Broadcast: Usuario #{inspect emisor} envió un broadcast"
        usuariosRestantes = filter(usuarios, emisor)
        send self, {emisor, usuariosRestantes, :broadcast, text}
#        IO.puts "SERVER: Broadcast: fin broadcast"
        loop(usuarios)
      {_, [], :broadcast, _} ->
        loop(usuarios)
      {emisor, [receptor|restantes], :broadcast, text} ->
#        IO.puts "SERVER: Broadcast: restantes #{inspect restantes}"
        send self, {emisor, receptor.pid, :enviar, text}
        send self, {emisor, restantes, :broadcast, text}
        loop(usuarios)
      {emisor, receptor, :enviar, text} ->
        receptorUser = getUsuario(usuarios, receptor)
#        IO.puts ":enviar emisor #{inspect emisor} receptor #{inspect receptor} #{inspect receptorUser} " 
        if (!isMuted(receptorUser, emisor)) do
#          IO.puts "SERVER-':enviar' a #{inspect receptor}"
          send receptor, {self, emisor, :recibir, text}
        else
#          IO.puts "SERVER-':recibir' Usuario #{inspect emisor} fue silenciado por #{inspect receptor}"
        end
        loop(usuarios)
      {emisor, receptor, :message, text} ->
        send self, {emisor, receptor, :enviar, text}
        loop(usuarios)
      {receptor, :visto, text} -> 
        usuariosRestantes = filter(usuarios, receptor)
        send self, {receptor, usuariosRestantes, :visto, text}
        loop(usuarios)
      {_, [], :visto, _} -> 
#        IO.puts "SERVER: visto: fin recursividad"
        loop(usuarios)
      {lector, [emisor|restantes], :visto, text} -> 
        send self, {lector, emisor.pid, :visto, text}
        send self, {lector, restantes, :visto, text}
        loop(usuarios)
      {lector, emisor, :visto, text} -> 
#        IO.puts ":visto emisor #{inspect emisor}" # User #{inspect emisorUser} 
      	emisorUser = getUsuario(usuarios, emisor)
        if (!isMuted(emisorUser, lector)) do
	    	  send emisor, {lector, :visto, text}
        else
#          IO.puts "SERVER-':visto' Usuario #{inspect lector} fue silenciado por #{inspect emisor}"
        end
        loop(usuarios)
      {emisor, :escribiendo} ->
        usuariosRestantes = filter(usuarios, emisor)
        send self, {emisor, usuariosRestantes, :escribiendo}
        loop(usuarios)
      {_, [], :escribiendo} ->
#        IO.puts "SERVER: escribiendo: fin recursividad"
        loop(usuarios)
      {emisor, [receptor|restantes], :escribiendo} ->
#        IO.puts ":escribiendo varios - receptor #{inspect receptor} #{inspect restantes}"
        send self, {emisor, receptor.pid, :escribiendo}
        send self, {emisor, restantes, :escribiendo}
        loop(usuarios)
      {emisor, receptor, :escribiendo} ->
#        IO.puts ":escribiendo receptor #{inspect receptor}" #  #{inspect receptorUser} 
        receptorUser = getUsuario(usuarios, receptor)
        if (!isMuted(receptorUser, emisor)) do
          send receptor, {emisor, :escribiendo}
        else
#          IO.puts "SERVER-':escribiendo' Usuario #{inspect receptor} fue silenciado por #{inspect emisor}"
        end
        loop(usuarios)
      {lector, emisor, :silenciar} -> 
        usuario = getUsuario(usuarios, lector)
        restantes = filter(usuarios, lector)
        usuarios = List.insert_at(restantes, -1, 
                                updateMute(usuario, 
                                addMute(usuario, emisor)))
#        IO.puts "SERVER-':silenciar' Usuario #{inspect emisor} silenciado por #{inspect lector}"
        loop(usuarios)
	  {pid, _ } -> 
	  	send pid, {:error, 'Invalid action from #{inspect pid}'}
    end
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
      {serverPid, emisor, :recibir, text} -> 
        IO.puts "CLIENT-#{inspect self}: Recibí mensaje de #{inspect emisor}"
        :timer.sleep(3* 1000)
        send self, {serverPid, emisor, :leer, text}
        loop(server)
      {serverPid, emisor, :leer, text} -> 
      	IO.puts "CLIENT-#{inspect self}: #{inspect emisor} dice: #{inspect text}"
      	send serverPid, {self, :visto, text}
      	loop(server)
      {receptor, :visto, text} ->
      	IO.puts "CLIENT-#{inspect self}: #{inspect receptor} ha visto el mensaje: #{inspect text}"
      	loop(server)
      {emisor, :escribiendo} ->
      	IO.puts "CLIENT-#{inspect self}: #{inspect emisor} está escribiendo..."
      	loop(server)
      {:escribir, texto} ->
        send server, {self, :escribiendo}
        :timer.sleep(3* 1000)
        send server, {self, :message, texto}
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
    #loop(server)
  end
end
