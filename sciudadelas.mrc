;Ciudadelas servidor
;GNU 2004 kat@fiade.com

on 1:exit: { unset %sciudadelas.v.* }

dialog puertoocupado {

  title $texto(9)
  size -1 -1 136 72
  option dbu
  text $texto(1), 1, 8 8 113 32, center
  button "Ok", 2, 48 48 37 12,ok

}

alias crea_partida {

  if (!%sciudadelas.f.personajes) { %sciudadelas.f.personajes = 1 2 3 4 5 6 7 8 }

  window -eh @sciudadelas
  sockclose sciudadelas*

  ;nos aseguramos de que podemos poner ese puerto en escucha...
  if ( $portfree(%sciudadelas.f.puerto) == $false) {

    dialog -m puertoocupado puertoocupado  
    did -oe jugar 16 1 $texto(12)
    did -b jugar 22

  } 
  else {

    socklisten sciudadelasLISTEN %sciudadelas.f.puerto

    ;si estamos conectados a servidor central, anunciamos nuestra partida
    ;si hay espacios en blanco en el nombre de partida, los sustituimos por "_"
    if ((%cciudadelas.f.listados) && ($sock(listados))) { sockwrite -n listados P $replace(%sciudadelas.f.partida,$chr(32),_) %sciudadelas.f.puerto %sciudadelas.f.nat }

    echo @sciudadelas * $texto(70)

    ;creamos nuestra lista de control de jugadores
    window -c @sjugadores
    window -hl @sjugadores

    ;preparamos mazo: cargamos distritos, eliminamos tokens sobrantes y añadimos los necesarios, barajamos.
    window -c @sdistritos
    window -hl @sdistritos
    loadbuf -e @sdistritos ciudadelas/distritos.txt

    var %c = 0 , %total = $line(@sdistritos,0)
    while ( %c < %total ) {
      inc %c
      rline @sdistritos %c $addtok( $deltok( $line(@sdistritos,%c) , 6- , 32 ) , M , 32)
    }

    sciudadelas.shuffle @sdistritos

    ;si jugamos con el diplomático, quitamos el cementerio del mazo
    if ( $istok(%sciudadelas.f.personajes,17,32) == $true ) { dline @sdistritos $fline(@sdistritos,66 $+ $chr(32) $+ *,1) }

    ;si no hay asesino, quitamos el hospital del mazo
    if ( $istok(%sciudadelas.f.personajes,1,32) == $false ) { dline @sdistritos $fline(@sdistritos,73 $+ $chr(32) $+ *,1) }

    unset %sciudadelas.v.pos

    reset_personajes

  }

}

alias reset_personajes {

  carga_personajes @spersonajes %sciudadelas.f.personajes

  ;eliminamos todo lo que nos sobra de dicha lista...
  var %c = 0, %total = $line(@spersonajes,0)
  while (%c < %total) {
    inc %c
    rline @spersonajes %c $addtok( $deltok( $line(@spersonajes,%c) , 3- , 32 ) ,L,32)
  }

}

alias inicia_partida {

  ;cerramos puerto de escucha
  sockclose sciudadelasLISTEN

  ;si estamos conectados a servidor central, cerramos la partida
  if ((%cciudadelas.f.listados) && ($sock(listados))) { sockwrite -n listados CP %sciudadelas.f.partida %sciudadelas.f.puerto }

  ;enviamos orden de empiece de partida para que dibujen la @mesa
  sciudadelas.msg sciudadelasC* S %sciudadelas.f.personajes

  ;ahora, enviamos a todos los sockets los nombres de los jugadores
  var %c = 0 , %total = $sock(sciudadelasC*,0)

  ;esto es un marcador que nos indica en qué punto del mazo de distritos estamos
  ;nota que NO es una variable local
  %sciudadelas.v.pos = 0

  ;seleccionamos un jugador al azar para que sea la corona el primer turno
  var %corona = $rand(1,%total)

  while ( %c < %total ) {

    inc %c
    if ( %c = %corona ) {
      sciudadelas.msg sciudadelasC* N $sock(sciudadelasC*,%c).mark 0 0 2 1 
      rline @sjugadores %c $puttok($line(@sjugadores,%c),1,5,32)
    }
    else { sciudadelas.msg sciudadelasC* N $sock(sciudadelasC*,%c).mark 0 0 2 }

    ;aprovechamos el bucle para dar a cada jugador sus 4 cartas iniciales...

    roba_cartas $gettok( $line(@sjugadores,%c) ,1,32) 4

  }

  descarta_bocarriba
  descarta_bocabajo

  ;una vez repartido todo, iniciamos la secuencia de elección de personaje
  ;¡sólo el cliente que elige debe saber qué cartas hay!

  var %corona = $corona , %s = $damesocket(%corona)

  sciudadelas.msg %s P %corona $personajes
  sciudadelas.msge %s P %corona

}

;roba_cartas jugador numero_cartas <motivo> asigna cartas del mazo al jugador.
;el tercer parámetro es opcional y sirve para justificar robos "extra" por maravillas o personajes.
;si usamos $roba_cartas(), además de lo anterior, recibiremos como resultado las cartas dadas

alias roba_cartas {

  cartas $1 + $2
  status $1

  sciudadelas.msg sciudadelasC* GCM $1-

  var %c = 0
  while (%c < $2) {

    inc %c
    inc %sciudadelas.v.pos
    var %carta = $line(@sdistritos,%sciudadelas.v.pos)
    rline @sdistritos %sciudadelas.v.pos $puttok(%carta , $1 ,6,32)
    var %cartas = $addtok(%cartas,$gettok(%carta,1,32),32)

  }
  sciudadelas.msg $damesocket($1) GC %cartas

  return %cartas

}

;todeck idcarta1 idcarta2 ...
;asigna la letra M a la carta (osea, la "mete" en el Mazo) y la coloca al final del mismo
;esta función, al contrario que roba_cartas, no actualiza 
;información sobre la mano del jugador, puntos ni envía mensajes

alias todeck {

  var %x = 0 , %total = $numtok($1-,32)

  while (%x < %total) {

    inc %x

    var %id = $gettok($1-,%x,32)
    var %c = $fline(@sdistritos, %id $+ $chr(32) $+ * ,1) , %l = $line(@sdistritos,%c)
    var %l = $puttok(%l,M,6,32)


    ;rline @sdistritos %c $puttok(%l,M,6,32)

    dline @sdistritos %c
    aline @sdistritos %l

  }

  ;¡NOTA!: al quitar una carta "asignada" y moverla al final, estamos haciendo que nuestro puntero
  ;%sciudadelas.v.pos "avance" hacia adelante, con lo que nos saltamos cartas que no han salido y hacemos
  ;más probable que los jugadores vean en juego cartas de las que se han descartado.
  ;La solución pasa por hacer retroceder %sciudadelas.v.pos tanto como cartas hayamos movido

  dec %sciudadelas.v.pos %total

}

;descartamos cartas bocarriba según reglas en uso...
;marcamos las descartadas bocarriba con "DU"
;rey y emperador NO pueden ser descartados bocaarriba

alias descarta_bocarriba {

  if ($reglas) {
    var %c = 0, %total = $reglas

    while (%c < %total) {
      inc %c
      var %n = $rand(1,8)
      if ((%n == 4) || (%n == 13)) { dec %c }
      else {
        var %carta = $line(@spersonajes,%n)
        if ( $gettok(%carta,3,32) != L ) { dec %c }
        else {
          rline @spersonajes %n $puttok(%carta,DU,3,32) 
          sciudadelas.msg sciudadelasC* DU $gettok(%carta,1,32)
        }
      }
    }
  }

}

;descarta_bocabajo <numero> marca con "DD" la carta pasada como parámetro.
;si no se pasa parámetro, elige una carta al azar de entre aquellas que NO
;estén marcadas ni como pertenecientes a un jugador ni como descartadas.

alias descarta_bocabajo {

  if ($1) {

    rline @spersonajes $1 $puttok( $line(@spersonajes,$1) ,DD,3,32) 
    sciudadelas.msg sciudadelasC* DD

  }
  else {

    ;sólo elegimos entre las que están L(ibres)
    var %c = 0 , %total = $fline(@spersonajes,* $+ $chr(32) $+ L,0)

    if (%total) {

      var %n = $rand(1,%total) , %nn = $fline(@spersonajes,* $+ $chr(32) $+ L,%n)
      var %carta = $line(@spersonajes, %nn )

      rline @spersonajes %nn $puttok(%carta,DD,3,32) 
      sciudadelas.msg sciudadelasC* DD

    }

  }

}

;$corona: nos da el nombre del jugador que tiene la corona en ese momento
;/corona nombrejugador
;si pasamos un nombre de jugador como parámetro, pondrá la corona en manos de ese jugador y notificará el cambio
;asignamos al azar si el destinatario está desconectado. Gestionamos maravilla "sala del trono".

alias corona {

  var %c = 0, %total = $line(@sjugadores,0)
  while (%c < %total) {

    inc %c
    var %linea = $line(@sjugadores,%c)

    ;encontramos la corona
    if ( $gettok(%linea,5,32 ) ) {

      var %nombre_corona = $gettok(%linea,1,32)

      ;si no nos han pasado parámetro, devolvemos la info pedida sin más
      if (!$1) { return %nombre_corona }

      ;si no, se trata de asignar a un nuevo jugador la corona
      else {

        var %nl = $fline(@sjugadores,$1 $+ $chr(32) $+ *,1)

        ;puede darse el caso de que el jugador destinatario de la corona haya desconectado,
        ;si es así, elegimos a uno de los restantes al azar
        if (!%nl) { var %nl = $rand(1, $line(@sjugadores,0)) }

        var %linea2 = $line(@sjugadores,%nl) , %nombre_jugador = $gettok(%linea2,1,32)

        ;si nos piden que asignemos corona a quien ya la tiene, paramos
        if (%nombre_corona == %nombre_jugador) { return }
        else {

          rline @sjugadores %c $puttok(%linea,0,5,32)
          rline @sjugadores %nl $puttok(%linea2,1,5,32)

          ;si alguien tiene construida la sala del trono (id 80),
          ;le damos una moneda de oro porque la corona se ha movido
          var %sala_del_trono = $line(@sdistritos, $fline(@sdistritos,80 $+ $chr(32) $+ *,1) )
          if ($gettok(%sala_del_trono,4,32)) {

            var %owner_saladeltrono = $gettok(%sala_del_trono,6,32)
            if (%owner_saladeltrono != M) {

              oro %owner_saladeltrono +1
              sciudadelas.msg HT %owner_saladeltrono
              ;si es uno de los implicados en el cambio de corona, no enviamos un status porque lo enviamos luego...
              if ( (%owner_saladeltrono == %nombre_corona) || (%owner_saladeltrono == %nombre_jugador) ) { ;no hablamos }
              else { status %owner_saladeltrono }

            }
          }
          status %nombre_corona
          status %nombre_jugador
          return
        }
      }
    }

  }

  ;si estamos aquí, es porque ningún jugador tiene la corona
  ;algo no ha ido bien, quizás haya desconectado, asignamos a quien nos dicen o al azar
  var %nl = $fline(@sjugadores, $1 $+ $chr(32) $+ *,1)

  if (!%nl) { var %nl = $rand(1, $line(@sjugadores,0)) }

  var %linea2 = $line(@sjugadores,%nl) , %nombre_jugador = $gettok(%linea2,1,32)
  rline @sjugadores %nl $puttok(%linea2,1,5,32)
  status %nombre_jugador
  return %nombre_jugador

}

;$personajes nos devuelve los personajes elegibles en ese momento
alias personajes {

  var %c = 0 , %total = $line(@spersonajes,0)
  while ( %c < %total ) {

    inc %c
    var %personaje = $line(@spersonajes,%c)
    if ( $gettok(%personaje,3,32) == L ) { var %elegibles = $addtok(%elegibles, $gettok(%personaje,1,32) ,32) }

  }

  return %elegibles

}

;$reglas devuelve el número de descartes bocarriba en función del número de jugadores y de si usamos 8 ó 9 personajes
;actualiza personajes usables en función del número de jugadores
;esto es necesario para los cambios de reglas que se producen durante el juego cuando alguien desconecta
alias reglas {

  var %n = $line(@sjugadores,0)

  ;si juegan menos de 3 tios, cambiamos emperador por rey
  if (%n < 3) {
    %sciudadelas.f.personajes = $reptok(%sciudadelas.f.personajes,13,4,1,32)
    reset_personajes
  }
  ;si juegan menos de 4 tios, quitamos 9º personaje
  if (%n < 4) {
    %sciudadelas.f.personajes = $remtok(%sciudadelas.f.personajes,9,1,32)
    %sciudadelas.f.personajes = $remtok(%sciudadelas.f.personajes,9,1,32)
    reset_personajes
  }

  if ($numtok(%sciudadelas.f.personajes,32) < 9) {
    if ( %n == 4 ) { return 2 }
    if ( %n == 5 ) { return 1 }
  }
  else {
    if ( %n == 4 ) { return 3 }
    if ( %n == 5 ) { return 2 }
    if ( %n == 6 ) { return 1 }
  }
  return 0

}

;------------------------------------ SOCKETS

on 1:socklisten:sciudadelasLISTEN:{
  :setname
  var %n = sciudadelasC $+ [ $ctime ]
  if ($sock(%n,1)) { goto setname }
  sockaccept %n
  echo @sciudadelas $time 2* $texto(71) $sock( %n ).ip
}

;cuando alguien escribe en el socket lo leemos en %d
;y lo mandamos a procesar
on 1:sockread:sciudadelasC*:{
  var %d = 0
  sockread -n %d
  if (%d) {
    var %mark = $sock( $sockname ).mark
    if ( %mark ) { echo @sciudadelas $time 5< $+ %mark $+ > %d }
    else { echo @sciudadelas $time 5< $+ $sock($sockname).ip $+ > %d }
    sciudadelas.procesa $sockname %d 
  }
}

;cuando alguien desconecta informamos al resto de jugadores y borramos de listado interno
;además, trataremos de evitar que la desconexión deje la partida colgada
on 1:sockclose:sciudadelasC*:{
  var %n = $sock($sockname).mark
  if (%n) {

    echo @sciudadelas $time 2* $texto(72) $sock( $sockname ).ip ( %n )
    sciudadelas.msg sciudadelasC* Q %n
    dline @sjugadores $fline(@sjugadores, %n $+ $chr(32) $+ *,1)

    ;si era el único conectado, reseteamos todo
    if ( !$sock(sciudadelasC*,0) ) {

      sockclose sciudadelas*
      did -oe jugar 16 1 $texto(12)
      did -oe jugar 17 1 $texto(13)
      did -e jugar 13,1,2,3,7
      did -o jugar 7 1 $texto(8) 

    }
    else {

      ;si estábamos jugando, miramos a ver si ha sido tan cabrón de salirse en su turno sin acabarlo;
      ;de ser así, saltamos turno como corresponda

      if ( %n == $gettok(%sciudadelas.v.turno,2,32) ) {

        if ( $gettok(%sciudadelas.v.turno,1,32) == $ultimo ) {

          sciudadelas.msg sciudadelasC* ET $gettok(%sciudadelas.v.turno,1,32) DC

          var %ganador = $elige_ganador
          if (%ganador) { 

            ;se acabó la partida

            ;borramos variables temporales del servidor
            unset %sciudadelas.v.*

            ;informamos de final de partida
            sciudadelas.msg sciudadelasC* EG %ganador

          }
          else {

            ;al acabar la ronda, borramos variables de Bruja
            unset %sciudadelas.v.bruja 
            unset %sciudadelas.v.embrujado

            ;también limpiamos variable del recaudador...
            unset %sciudadelas.v.construida

            elige_personaje

          }

        }
        else {

          var %c = $fline(@spersonajes, $gettok(%sciudadelas.v.turno,1,32) $+ $chr(32) $+ * ,1)
          inc %c
          var %p = $gettok( $line(@spersonajes,%c) ,1,32)
          sciudadelas.msg sciudadelasC* ET $gettok(%sciudadelas.v.turno,1,32) DC
          juega_personaje %p 

        }
      }

      ;si no se ha salido en su turno de juego, tal vez se haya salido en la ronda de elección,
      ;de ser así, la reiniciamos para ajustar descartes al nuevo número de jugadores
      if (($personajes) && (%sciudadelas.v.pos)) { elige_personaje }

    }
  }
}

;envia un mensaje al socket pasado como argumento
alias sciudadelas.msg {
  if ( $sock($1) ) {
    echo @sciudadelas $time 2<S> $2-
    sockwrite -n $1 $2- 
  }
  else { echo sciudadelas.msg: ERROR -> el socket " $1 " no existe! }
}

;envia un mensaje a todos menos al socket especificado
alias sciudadelas.msge {
  var %x = 0 , %y = $sock(sciudadelasC*,0)
  while (%x < %y) {
    inc %x
    var %s = $sock(sciudadelasC*,%x)
    if (%s != $1) { sciudadelas.msg %s $2- }
  }
}

;damesocket nombrejugador
;devuelve el nombre del socket correspondiente al jugador

alias damesocket {
  var %c = 0, %total = $sock(sciudadelasC*,0)
  while (%c < %total) {
    inc %c
    if ( $sock(sciudadelasC*,%c).mark == $1 ) { return $sock(sciudadelasC*,%c) }
  }
}


;------------------------------------ SOCKETS EOF

;JUEGO

;función para "barajar". En nuestro caso cada "mazo" de cartas está representado por una @ventana
;esta funcion tiene como argumento el nombre de la ventana y se encarga de distribuir "al azar" las
;lineas de la misma
alias sciudadelas.shuffle {
  if ($1) {
    if ($window($1)) {
      window -hl @temp
      clear @temp
      var %n = $line($1,0)
      while (%n) {
        var %x = $rand(1, %n )
        var %l = $line($1,%x)
        aline @temp %l
        dline $1 %x
        dec %n
      }
      window -c $1
      renwin @temp $1
    }
  }
}

alias bal_room {

  ;si está construida la BAL ROOM y su dueño tiene la corona, cuidadín
  var %bal_room = $line(@sdistritos, $fline(@sdistritos, 82 $+ $chr(32) $+ * ,1)) 
  var %bal_room_built = $gettok(%bal_room,4,32)

  if ( %bal_room_built ) {

    var %bal_room_owner = $gettok(%bal_room,6,32)
    var %j = $gettok(%sciudadelas.v.turno,2,32)
    var %p = $gettok(%sciudadelas.v.turno,1,32)

    if ( (%bal_room_owner == $corona) && (%bal_room_owner != %j) ) { 
      if (%sciudadelas.v.balroom) { return }
      else { 

        sciudadelas.msg sciudadelasC* ET %p BRF

        var %c = $fline(@spersonajes, %p $+ $chr(32) $+ *,1) | inc %c

        if (%c > $numtok(%sciudadelas.f.personajes,32) ) {
          elige_personaje 
          halt
        }
        else {
          var %p = $gettok( $line(@spersonajes,%c) ,1,32)
          juega_personaje %p
          halt
        }

      }

    }
    else { return }

  }
  else { return }

}

;asigna_personaje <jugador> <numeropersonaje> -> asigna ese personaje y continua con la secuencia de elección
;si pasamos un tercer parámetro, se entiende que venimos de un descarte bocaabajo, no asignamos personaje
;sino que avanzamos un paso en la ronda
alias asigna_personaje {

  ;cuando un jugador elige un personaje, le marcamos como tal y "enviamos las cartas" al siguiente,
  ;el proceso se repite hasta que sólo quede una carta libre; por fuerza, ésta se descarta bocabajo
  ;y enviamos señal de inicio de turno al personaje número uno

  if (!$3) {
    var %c = $fline(@spersonajes, $2 $+ $chr(32) $+ * ,1)
    rline @spersonajes %c $puttok($line(@spersonajes,%c), $1 ,3,32)

  }

  ;salto

  var %personajes = $numtok($personajes,32) , %jugadores = $line(@sjugadores,0)
  ;reglas para 2 jugadores;cuando quedan 5 y 3 personajes, enviamos orden para descarte bocaabajo
  if ( (%jugadores == 2) && ( (%personajes == 5) || (%personajes == 3) ) ) {
    sciudadelas.msg $damesocket($1) MDD $personajes
    halt
  }

  if (%personajes > 1) {

    var %l = $fline(@sjugadores, $1 $+ * ,1)

    if ( %l == %jugadores ) { %l = 1 }
    else { inc %l }

    var %j = $gettok( $line(@sjugadores,%l) ,1,32 ) , %s = $damesocket( %j )

    sciudadelas.msg %s P %j $personajes
    sciudadelas.msge %s P %j

  }
  else { 

    descarta_bocabajo

    juega_personaje $gettok($line(@spersonajes,1) ,1,32)

  }
  return

}

alias sciudadelas.procesa {

  var %n = $sock($1).mark

  if ($2 == N) {

    sockmark $1 $3 
    ;nombre puntos cartas oro corona(1/0) numero_personaje 
    aline @sjugadores $3 0 0 2 0 0
    var %c = 0, %total = $sock(sciudadelasC*,0)
    while (%c < %total) {
      inc %c
      sciudadelas.msg $1 NJ $sock(sciudadelasC*,%c).mark
    }
    sciudadelas.msge $1 NJ $3
    return

  }

  if ($2 == Q) {

    sciudadelas.msge $1 Q %n $3 
    return

  }

  if ($2 == M) { 

    sciudadelas.msge $1 M %n $3- 

    ;bal_room -> si habla en su turno y dice la frase mágica, lo recordamos
    if ( ($3- == $texto(244)) && ($gettok(%sciudadelas.v.turno,2,32) == %n) ) { %sciudadelas.v.balroom = 1 }

    return

  }

  if ($2 == P) {
    asigna_personaje %n $3
    return
  }

  if ($2 == DD) {

    ;partida entre 2 jugadores, eligen descarte
    ;comprobamos que se trata de una carta libre (no vayan a pisar la elección del contrario)

    var %npersonaje = $fline(@spersonajes, $3 $+ $chr(32) $+ *,1), %personaje = $line(@spersonajes, %npersonaje)
    var %estado = $gettok(%personaje,3,32)

    if (%estado == L) { 

      ;descartamos personaje, informamos de descarte y seguimos ronda de elección
      rline @spersonajes %npersonaje $puttok(%personaje,DD,3,32)
      sciudadelas.msg sciudadelasC* DD

      asigna_personaje %n $3 1

    }
    else { sciudadelas.msg $1 MDD $personajes }
    return

  }

  ;maravilla bal room -> si el tio no ha dado las gracias e intenta hacer algo, pierde turno
  bal_room $1-


  if ($2 == K) {

    ;marcamos como muerto e informamos

    var %c = $fline(@spersonajes, $3 $+ $chr(32) $+ * ,1) , %linea = $line(@spersonajes, %c )
    var %jugador = $gettok(%linea,3,32), %linea = $puttok( %linea ,K,3,32 ) , %linea = $addtok( %linea ,%jugador,32) 

    rline @spersonajes %c %linea
    sciudadelas.msg sciudadelasC* K %n $3-
    return

  }

  if ($2 == R) {

    ;marcamos como robado e informamos
    var %c = $fline(@spersonajes, $3 $+ $chr(32) $+ * ,1)
    rline @spersonajes %c $addtok( $line(@spersonajes,%c) ,R,32 )
    sciudadelas.msg sciudadelasC* R %n $3-
    return

  }

  if ($2 == W) {

    ;le mandamos una lista con la mano del jugador seleccionado
    var %c = 0 , %total = $fline(@sdistritos, * $+ $chr(32) $+ $3,0)

    while (%c < %total) {
      inc %c 
      var %carta = $line(@sdistritos, $fline(@sdistritos, * $+ $chr(32) $+ $3,%c) )
      if ( !$gettok(%carta,4,32) ) { var %cartas = $addtok(%cartas, $gettok(%carta,1,32) ,32) }
    }

    sciudadelas.msg $1 WL $3 %cartas
    return

  }

  if ($2 == WC) {

    ;averiguamos de quién es la carta robada, actualizamos datos e informamos
    var %nc = $fline(@sdistritos,$3 $+ $chr(32) $+ *,1), %carta = $line(@sdistritos,%nc)
    var %owner = $gettok(%carta,6,32)

    var %carta = $puttok(%carta,%n,6,32)
    rline @sdistritos %nc %carta

    cartas %n +1
    cartas %owner -1
    status %n
    status %owner

    ;a la víctima le mandamos en el mensaje el id de la carta para que la borre,
    ;el resto o bien no necesitan saberlo o bien es el hechicero y ya lo conoce.
    sciudadelas.msg $damesocket(%owner) WC %n %owner $3
    sciudadelas.msge $damesocket(%owner) WC %n %owner
    return

  }

  if ($2 == NC) {

    ;Navegante pilla 4 cartas
    roba_cartas %n 4 $texto(152)
    return

  }

  if ($2 == NG) {

    ;navegante pilla 4 monedas
    sciudadelas.msg sciudadelasC* NG %n
    oro %n +4
    status %n
    return

  }

  if ($2 == GG) { 

    sciudadelas.msg sciudadelasC* GG %n
    oro %n +2
    status %n
    return

  }

  if ($2 == MU) {

    ;colocan una carta bajo el museo
    var %nc = $fline(@sdistritos, $3 $+ $chr(32) $+ *,1) , %carta = $line(@sdistritos,%nc)
    rline @sdistritos %nc $puttok(%carta,MU,6,32)

    cartas %n -1
    status %n

    sciudadelas.msg sciudadelasC* MU %n
    return

  }

  if ($2 == LH) {

    ;coge una carta con el faro
    cartas %n +1
    status %n
    sciudadelas.msg sciudadelasC* GCM %n 1 $texto(225)

    var %c = $fline(@sdistritos, $3 $+ $chr(32) $+ *,1), %carta = $line(@sdistritos,%c)
    dline @sdistritos %c
    inc %sciudadelas.v.pos
    iline @sdistritos %sciudadelas.v.pos  $puttok(%carta,%n,6,32)
    return

  }

  if ($2 == GEC) {

    roba_cartas %n 2 $texto(73)
    return

  }

  if ($2 == GC) {

    var %biblioteca = $maravillas(%n,0,62)
    var %observatorio = $maravillas(%n,0,68)

    ;robo normal: coge 2 y se tiene que descartar de 1
    if ( (!%biblioteca) && (!%observatorio) ) {
      var %cartas =  $roba_cartas( %n , 2 )
      sciudadelas.msg $1 DC %cartas
    }

    ;biblioteca sin observatorio: coge 2 y no tiene que descartarse de nada
    if ((%biblioteca) && (!%observatorio)) { roba_cartas %n 2 }

    ;observatorio sin biblioteca: coge 3 y se descarta de 2
    ;observatorio y biblioteca: coge 3 y descarta 1
    ;mismo mensaje en esta fase, al recibir el descarte habrá que comprobar de cuánto se descarta
    if ( ((!%biblioteca) && (%observatorio)) || ((%biblioteca) && (%observatorio)) ) { 
      var %cartas =  $roba_cartas( %n , 3 , $texto(108) )
      sciudadelas.msg $1 DC %cartas
    }
    return

  }

  if ($2 == F) {

    ;comprobamos que la tiene construida
    if ( !$maravillas(%n,0,67) ) { sciudadelas.msg $1 E 75 }
    else {

      ;paga 2 monedas de oro -si las tiene- y roba 3 cartas que no tiene que descartar
      var %c = $fline(@sjugadores, %n $+ * ,1 ) , %l = $line(@sjugadores,%c)
      var %oro = $gettok(%l,4,32)
      if (%oro > 1) {

        var %l = $puttok(%l , $calc( %oro - 2 ) ,4,32)
        rline @sjugadores %c %l
        roba_cartas %n 3 $texto(40)

      }
      else { sciudadelas.msg $1 E 74 }
    }
    return

  }

  if ($2 == GD) {

    ;convertimos personajes "extra" a su equivalente clásico
    if ( $3 > 9 ) {
      if ($3 == 13) { var %p = 4 }
      if ($3 == 14) { var %p = 5 }
      if ($3 == 17) { var %p = 8 }
    }
    else { var %p = $3 }

    cobra_distritos %n %p
    return

  }

  if ($2 == EM) {

    ;el emperador da la corona
    corona $3
    sciudadelas.msg sciudadelasC* EM %n $3

    ;si el jugador que recibe la corona no tiene ni cartas ni oro,
    ;avisamos al emperador para que no espere y siga jugando

    ;comprobamos oro
    var %victima = $line(@sjugadores, $fline(@sjugadores, $3 $+ $chr(32) $+ *,1))

    ;como ya he invocado la línea, no me merece la pena llamar a $oro y $cartas para esto
    var %oro = $gettok( %victima ,4,32) , %cartas = $gettok(%victima,3,32)
    if ( (!%oro) && (!%cartas) ) { sciudadelas.msg sciudadelasC* EMN $3 %n }
    return

  }

  if ($2 == EMG) {

    ;el jugador que recibe corona paga al emperador 1 moneda de oro

    ;fue embrujado el emperador?
    if (%sciudadelas.v.embrujado == 13) { var %jemperador = %sciudadelas.v.bruja }
    else { var %jemperador = $gettok($line(@spersonajes, $fline(@spersonajes,13 $+ $chr(32) $+ *,1)) ,3,32) }

    oro %jemperador +1
    oro %n -1
    status %jemperador
    status %n

    sciudadelas.msg sciudadelasC* EMG %n %jemperador
    return

  }

  if ($2 == EMC) {

    ;el jugador que recibe corona paga al emperador una carta

    ;fue embrujado el emperador?
    if (%sciudadelas.v.embrujado == 13) { var %jemperador = %sciudadelas.v.bruja }
    else { var %jemperador = $gettok($line(@spersonajes, $fline(@spersonajes,13 $+ $chr(32) $+ *,1)) ,3,32) }

    ;actualizamos en servidor el propietario de la carta cedida
    var %ncarta = $fline(@sdistritos,$3 $+ $chr(32) $+ *,1) , %carta = $line(@sdistritos,%ncarta)
    var %carta = $puttok(%carta,%jemperador,6,32)
    rline @sdistritos %ncarta %carta

    cartas %jemperador +1
    cartas %n -1
    status %jemperador
    status %n

    sciudadelas.msg sciudadelasC* EMC %n %jemperador $3
    return

  }

  if ($2 == DP) {

    ;recibimos distrito_del_diplomático=$3 distrito_víctima=$4
    var %nc1 = $fline(@sdistritos,$3 $+ $chr(32) $+ *,1) , %carta1 = $line(@sdistritos,%nc1)
    var %nc2 = $fline(@sdistritos,$4 $+ $chr(32) $+ *,1) , %carta2 = $line(@sdistritos,%nc2)
    var %owner1 = $gettok(%carta1,6,32) , %owner2 = $gettok(%carta2,6,32)
    var %precio1 = $gettok(%carta1,3,32) , %precio2 = $gettok(%carta2,3,32)

    ;¿intercambia un distrito que le pertenece?
    if ( %owner1 != $gettok($line(@spersonajes,$fline(@spersonajes,17 $+ $chr(32) $+ *,1)) ,3,32) ) { sciudadelas.msg $1 E 173 }
    else {

      ;¿pretende colarme un distrito del obispo?
      if ( %owner2 == $gettok($line(@spersonajes,$fline(@spersonajes,5 $+ $chr(32) $+ *,1)) ,3,32) ) { sciudadelas.msg $1 E 174 }
      else {

        ;es la bruja con el obispo embrujado?
        if ( (%owner2 == %sciudadelas.v.bruja) && (%sciudadelas.v.embrujado == 5) ) { sciudadelas.msg $1 E 174 }
        else {

          ;si alguno de los dos tiene 8 distritos construidos, abortamos
          if ( ( $distritos_construidos(%owner1) == $calc(8 - %sciudadelas.v.tb) ) || ( $distritos_construidos(%owner2) == $calc(8 - %sciudadelas.v.tb) ) ) { sciudadelas.msg $1 E 177 }
          else {

            ;si al cambiar alguno se queda con dos distritos iguales sin tener cantera, abortamos
            if ( (( $construida(%owner1, $gettok(%carta2,2,32) ) ) && ( !$maravillas(%owner1,0,61) ))  || (( $construida(%owner2, $gettok(%carta1,2,32) ) ) && ( !$maravillas(%owner2,0,61) )) ) { sciudadelas.msg $1 E 178 }
            else {

              var %dif = $calc(%precio2 - %precio1)

              ;tiene la víctima muralla construida?
              if ( $maravillas(%owner2,0,63) ) { inc %dif }

              ;el distrito objetivo está ornamentado?
              if ($gettok(%carta2,4,32) == 2) { inc %dif }

              var %ndiplomatico = $fline(@sjugadores,%n $+ $chr(32) $+ *,1) , %diplomatico = $line(@sjugadores, %ndiplomatico)
              var %nvictima = $fline(@sjugadores,%owner2 $+ $chr(32) $+ *,1) , %victima = $line(@sjugadores, %nvictima)


              ;si el distrito nuevo es más caro, que pague la diferencia
              if (%dif > 0) {
                var %dinero = $gettok(%diplomatico,4,32) , %vdinero = $gettok(%victima,4,32)
                if (%dif > %dinero) { sciudadelas.msg $1 E 175 }
                else { 

                  ;cambio de distritos pagando

                  ;intercambio propietarios en el servidor
                  rline @sdistritos %nc1 $puttok(%carta1,%owner2,6,32)
                  rline @sdistritos %nc2 $puttok(%carta2,%owner1,6,32)


                  ;incrementamos coste si la víctima tiene construida la muralla
                  if ( $maravillas(%owner2,0,63) ) { inc %dif }

                  sciudadelas.msg sciudadelasC* DP %owner1 %owner2 $3-

                  ;ajustamos dineros

                  oro %n - %dif
                  oro %owner2 + %dif
                  status %n
                  status %owner2

                }
              }
              else {

                ;cambio de distritos sin pagar 

                sciudadelas.msg sciudadelasC* DP %owner1 %owner2 $3-

                ;intercambio propietarios en el servidor
                rline @sdistritos %nc1 $puttok(%carta1,%owner2,6,32)
                rline @sdistritos %nc2 $puttok(%carta2,%owner1,6,32)

                var %diplomatico = $puttok(%diplomatico, $calcula_puntos(%n) ,2,32)
                rline @sjugadores %ndiplomatico %diplomatico
                sciudadelas.msg sciudadelasC* J %diplomatico

                var %victima = $puttok(%victima, $calcula_puntos(%owner2),2,32)
                rline @sjugadores %nvictima %victima
                sciudadelas.msg sciudadelasC* J %victima

              }

            }
          }
        }
      }
    }
    return

  }

  if ($2 == L) {

    ;usan el Laboratorio para descartar una carta y cobrar una moneda de oro, ¡ruines!

    ;comprobamos que tiene construido el laboratorio
    if ( !$maravillas(%n,0,69) ) { sciudadelas.msg $1 E 76 }
    else {

      ;comprobamos que tiene la carta en la mano
      var %nc = $fline(@sdistritos,$3 $+ $chr(32) $+ *,1) , %carta = $line(@sdistritos,%nc)
      var %owner = $gettok(%carta,6,32) , %construida = $gettok(%carta,4,32)
      if ((%owner == %n) && (%construida == 0)) {

        ;mandamos la carta al mazo
        todeck $3

        ;le apuntamos su miserable moneda de oro y le quitamos su carta

        cartas %n -1
        oro %n +1
        status %n

        sciudadelas.msg sciudadelas* L %n

      }
      else { sciudadelas.msg $1 E 77 }

    }
    return

  }

  if ($2 == BR) {

    ;memorizamos bruja y pardillo embrujado para futuras referencias
    %sciudadelas.v.embrujado = $3
    %sciudadelas.v.bruja = %n
    sciudadelas.msg sciudadelasC* BR %n $3
    return

  }

  if ($2 == PD) {

    ;destruir distrito con powderhouse (polvorín)
    var %owner = $gettok($line(@sdistritos, $fline(@sdistritos, $3 $+ $chr(32) $+ * ,1)),6,32)

    ;devolvemos al mazo cartas destruidas
    todeck $3
    todeck 76

    ;si era el museo, devolvemos al mazo las cartas que están bajo él
    if ($3 == 78) { todeck_museo }

    ;si era el campanario, dejamos las reglas de finalización de partida como estaban
    if ($3 == 79) { unset %sciudadelas.v.tb }

    ;si alguno de los jugadores había entrado en la lista de los bonos por cerrar, le sacamos
    set %sciudadelas.v.ocho = $remtok(%sciudadelas.v.ocho,%owner,1,32)
    set %sciudadelas.v.ocho = $remtok(%sciudadelas.v.ocho,%n,1,32)

    ;informamos a los clientes para que borren cartas
    sciudadelas.msg sciudadelasC* PD %n %owner $3

    ;para actualizar puntos, uso el penoso truco de sumar 0 de oro...
    oro %owner +1-1
    oro %n +1-1
    status %owner
    status %n
    return

  }

  if ($2 == KD) {

    ;si el distrito es el Torreón, no puede ser destruido
    if ($3 == 59) { sciudadelas.msg $1 E 15 }
    else {

      ;comprobamos que la víctima no es el obispo -vivo- o la Bruja con el poder del mismo, ¡atentos al cristo padre!

      var %ncarta = $fline(@sdistritos, $3 $+ $chr(32) $+ *,1) , %carta = $line(@sdistritos, %ncarta )
      var %j = $gettok( %carta ,6,32)
      var %lobispo = $line(@spersonajes, $fline(@spersonajes, 5 $+ $chr(32) $+ * ,1) ) , %obispo = $gettok( %lobispo ,3,32 ) 
      var %lbruja = $line(@spersonajes, $fline(@spersonajes, 10 $+ $chr(32) $+ * ,1) ) , %bruja = $gettok( %lbruja ,3,32 )
      if ((%j != %obispo) || ( (%j == %obispo) && (%sciudadelas.v.embrujado == 5) )) {
        if  ( ( %j != %bruja )  || ( ( %j == %bruja ) && ( %sciudadelas.v.embrujado != 5 ) ) ) {

          ;¿podrá pagarlo?
          var %coste = $gettok(%carta,3,32)
          dec %coste

          ;tiene la víctima muralla construida?
          if ( $maravillas(%j,0,63) ) { inc %coste }

          ;el distrito objetivo está ornamentado?
          if ($gettok(%carta,4,32) == 2) { inc %coste }

          var %jcl = $fline(@sjugadores,%n $+ $chr(32) $+ *,1) , %jc = $line(@sjugadores,%jcl), %oro = $gettok(%jc,4,32)

          if (%oro < %coste) { sciudadelas.msg $1 E 16 }
          else {

            ;si tiene 8 distritos construidos, no podemos romper nada
            if ($distritos_construidos(%j) < $calc(8 - %sciudadelas.v.tb) ) {

              ;devolvemos la carta al mazo
              todeck $3

              ;si era el museo, devolvemos al mazo las cartas que están bajo él
              if ($3 == 78) { todeck_museo }

              ;si era el campanario, dejamos las reglas de finalización de partida como estaban
              if ($3 == 79) { unset %sciudadelas.v.tb }

              ;recalculamos puntos y dinero, enviamos actualización y mensaje de distrito destruido a todos

              oro %n - %coste
              ;truco: sumo 0 oro a la víctima, así actualizo sus puntos
              oro %j +1-1
              status %n
              status %j

              sciudadelas.msg sciudadelasC* KD %n $3 %j

              %sciudadelas.v.destruida = $3

            }
            else { sciudadelas.msg $1 E 18 }
          }

        }
        else { sciudadelas.msg $1 E 17 }
      }
      else { sciudadelas.msg $1 E 17 }

    }
    return

  }

  if ( $2 == AR ) {

    if ( $oro(%n) ) {

      ;le quitamos una moneda
      oro %n -1

      ;en servidor controlamos el "ornamento" en el mismo campo que la construcción,
      ;de modo que una carta construida tiene "1" en ese campo y si está ornamentada
      ;tiene un "2"

      ;ornamentamos el distrito
      var %carta = $puttok(%carta,2,4,32)
      rline @sdistritos %ncarta %carta

      sciudadelas.msg sciudadelasC* AR %n $3

      status %n

    }
    else { sciudadelas.msg $1 E 190 }
    return

  }

  if ( $2 == CY ) {

    ;alguien usa el cementerio para recuperar la última carta destruida pagando una moneda de oro

    ;comprobamos que el jugador tiene construido el cementerio
    if ( $maravillas(%n,0,66) ) {

      ;comprobamos que tiene una moneda de oro
      if ( $oro(%n) ) {

        ;le asignamos en servidor la última carta destruida
        var %nc = $fline(@sdistritos, %sciudadelas.v.destruida $+ $chr(32) $+ *,1) , %carta = $line(@sdistritos,%nc)
        var %carta = $puttok(%carta,%n,6,32)

        ;NOTA: debemos mover la carta al "bloque inicial" de @sdistritos -cartas asignadas- y actualizar el puntero
        ;rline @sdistritos %nc %carta
        dline @sdistritos %nc
        inc %sciudadelas.v.pos
        iline @sdistritos %sciudadelas.v.pos %carta

        ;le quitamos una moneda, sumamos carta, actualizamos e informamos
        oro %n -1
        cartas %n +1
        status %n

        sciudadelas.msg sciudadelasC* CY %n %sciudadelas.v.destruida

      }
      else { sciudadelas.msg $1 E 79 }

    }
    else { sciudadelas.msg $1 E 80 }
    return

  }

  if ( $2 == C ) {

    ;cambio de algunas cartas con el mazo
    if ($3 == M) {

      ;marcamos las descartadas como pertenecientes al mazo y las pasamos al final del mismo
      todeck $4-

      var %total = $numtok($4-, 32)

      ;antes de darle cartas nuevas, le restamos las descartadas de su total
      cartas %n - %total

      ;le damos al jugador las cartas nuevas
      roba_cartas %n %total $texto(81)

    }

    ;cambio de mano de un jugador con la de otro
    else {

      ;hacemos lista de cartas en la mano del jugador víctima y del jugador mago
      var %c = 0 , %totalv = $fline(@sdistritos, * $+ $chr(32) $+ $3,0) , %totalm = $fline(@sdistritos, * $+ $chr(32) $+ %n,0)

      ;lista de cartas de la víctima en %cartasv
      while (%c < %totalv) {
        inc %c 
        var %carta = $line(@sdistritos, $fline(@sdistritos, * $+ $chr(32) $+ $3,%c) )
        if ( !$gettok(%carta,4,32) ) { var %cartasv = $addtok(%cartasv, $gettok(%carta,1,32) ,32) }
      }

      ;lista de cartas del mago en %cartasm
      var %c = 0
      while (%c < %totalm) {
        inc %c 
        var %carta = $line(@sdistritos, $fline(@sdistritos, * $+ $chr(32) $+ %n,%c) )
        if ( !$gettok(%carta,4,32) ) { var %cartasm = $addtok(%cartasm, $gettok(%carta,1,32) ,32) }
      }

      ;pasamos al mago las cartas de la lista de la víctima
      var %c = 0 , %total1 = $numtok(%cartasv,32)
      while (%c < %total1) {
        inc %c
        var %ncarta = $fline(@sdistritos, $gettok(%cartasv,%c,32) $+ $chr(32) $+ * ,1 ) , %carta = $line(@sdistritos,%ncarta)
        var %carta = $puttok(%carta,%n,6,32)
        rline @sdistritos %ncarta %carta

      }

      ;pasamos a la víctima las cartas de la lista del mago
      var %c = 0 , %total2 = $numtok(%cartasm,32)
      while (%c < %total2) {
        inc %c
        var %ncarta = $fline(@sdistritos, $gettok(%cartasm,%c,32) $+ $chr(32) $+ * ,1 ) , %carta = $line(@sdistritos,%ncarta)
        var %carta = $puttok(%carta,$3,6,32)
        rline @sdistritos %ncarta %carta
      }

      ;actualizamos número de cartas en la info del server sobre los jugadores
      ;para actualizar correctamente, le restamos a cada uno las que tenía y luego le sumamos las del otro
      cartas %n - %total2 + %total1
      cartas $3 - %total1 + %total2

      ;enviamos mensaje de cambio de cartas y listas actualizadas a los afectados 
      sciudadelas.msg sciudadelasC* CM %n $3
      sciudadelas.msg $1 C %cartasv
      sciudadelas.msg $damesocket($3) C %cartasm

      status %n
      status $3

    }
    return

  }

  if ($2 == DC) {

    var %total = $numtok($3-,32)

    ;metemos las cartas descartadas al final del mazo con propietario "M"
    todeck $3-

    ;actualizamos info del jugador
    cartas %n - %total
    status %n

    sciudadelas.msg sciudadelasC* DCM %n %total
    return

  }

  if ($2 == B) {

    ;comprobamos que el jugador tiene la carta (muy paranoico, sí, pero la peña está muy loca)
    var %nc = $fline(@sdistritos, $3 $+ $chr(32) $+ * ,1) , %carta = $line(@sdistritos,%nc)
    var %owner = $gettok(%carta,6,32)
    if ( %owner != %n ) { sciudadelas.msg $1 E 82 }
    else {

      ;comprobamos que no tiene construida ya una similar y si la tiene, que no tiene la maravilla de la cantera
      if ( ( $construida(%n, $gettok(%carta,2,32) ) ) && ( !$maravillas(%n,0,61) ) ) { sciudadelas.msg $1 E 28 }
      else {

        ;comprobamos que puede pagarla
        var %precio = $gettok( %carta ,3,32 )

        ;modificamos precio si tiene manufactura (id 77) construida y está construyendo una maravilla (campo 5 en @sdistritos)
        if ( ($maravillas(%n,0,77)) && (!$gettok(%carta,5,32)) ) { dec %precio }

        if (%precio > $oro(%n) ) { sciudadelas.msg $1 E 27 }
        else {

          ;cambiamos status de la carta a "construido" (token 4 de 0 a 1)
          rline @sdistritos %nc $puttok(%carta,1,4,32)

          ;si no es el Alquimista ni la Bruja con su habilidad, le quitamos el precio
          if ( ( $gettok( $line(@spersonajes, $fline(@spersonajes,15 $+ $chr(32) $+ *,1)) ,3,32) == %n ) && ($4 == 15) ) || ( (%n == %sciudadelas.v.bruja) && (%sciudadelas.v.embrujado == 15) ) { }
          else { 
            oro %n - %precio
          }

          ;si es su 8º (o 7º con faro) distrito, le apuntamos en la lista
          if  ( $distritos_construidos(%n) == $calc(8 - %sciudadelas.v.tb) ) { %sciudadelas.v.ocho = $addtok(%sciudadelas.v.ocho,%n,32) }

          ;quitamos la carta de su mano y actualizamos
          cartas %n -1

          ;informamos a todos de la construcción
          sciudadelas.msg sciudadelasC* B %n $3 

          ;es importante avisar antes de la construcción que actualizar, pues el cliente
          ;usa la actualización para reactivar botones...
          status %n

          ;recordamos última carta construida, para pagar al Recaudador
          ;si el que construye NO es el jugador que lo tiene, claro
          if ( $gettok($line(@spersonajes,$fline(@spersonajes,11 $+ $chr(32) $+ *,1)) ,3,32) != %n ) { 
            %sciudadelas.v.construida = %n $3 
          }

          ;si ha construido el faro (id 75), le enviamos info del mazo para que elija carta
          if ($3 == 75) { sciudadelas.msg $1 LH $lista_mazo }

        }
      }
    }
    return

  }

  if ($2 == TB) {
    ;usa el campanario, la partida terminará con 7 distritos salvo que el mismo sea destruido
    sciudadelas.msg sciudadelasC* TB %n
    %sciudadelas.v.tb = 1
    return

  }

  if ($2 == ET) {

    ;acabe quien acabe, limpiamos bal_room
    unset %sciudadelas.v.balroom

    ;si tiene construida la poorhouse y no tiene pelas, le damos una moneda de oro.
    ;No tengo claro si esto debería ir aquí o tras haber comprobado recaudador, no veo nada en las FAQ.
    if ( $maravillas(%n,0,74) && ($oro(%n) == 0) ) {

      oro %n +1
      status %n
      sciudadelas.msg sciudadelasC* PH %n

    }

    ;si tiene construido el parque y no tiene cartas en la mano, le damos 2 cartas
    if ( $maravillas(%n,0,81) && ($cartas(%n) == 0) ) {

      roba_cartas %n 2 $texto(231)

    }

    ;si alguien acaba su turno, unseteamos variables que puedan haberse creado y que ya no deban existir
    unset %sciudadelas.v.destruida

    ;Reina con Corona muerta
    if ($3 == 9) {

      ;fue EMBRUJADA la Reina?
      if (%sciudadelas.v.embrujado == 9) { var %jugadorreina = %sciudadelas.v.bruja }
      else { var %jugadorreina = %n }

      var %corona = $corona
      ;si el tio que tiene la corona está muerto la reina cobrará al acabar el turno
      ;osea, AHORA
      var %ncorona = $fline(@sjugadores,%corona $+ $chr(32) $+ *,1)
      var %muerto = $gettok($line(@spersonajes, %ncorona) ,3,32)
      if (%muerto == K) {

        var %nprevio = $calc(%ncorona - 1) , %nsiguiente = $calc(%ncorona + 1)

        ;si nprevio vale 0, le damos el valor de la última línea (nuestro registro no es circular, la mesa sí)
        if ( %nprevio == 0 ) { var %nprevio = $line(@sjugadores,0) }
        ;si nsiguiente vale más que jugadores existentes, le damos valor 1
        if ( %nsiguiente > $line(@sjugadores,0) ) { var %nsiguiente = 1 }

        var %nreina = $fline(@sjugadores,%jugadorreina $+ $chr(32) $+ *,1)
        if ( (%nreina == %nprevio) || (%nreina == %nsiguiente) ) {

          oro %jugadorreina +3
          status %jugadorreina

          sciudadelas.msg sciudadelasC* QG %jugadorreina

        }

      }
    }

    ;si el jugador ha construido, tiene dinero, el RECAUDADOR está vivo y en juego y no es el propio jugador,
    ;tendrá que pagarle una monedita al funcionario de la Agencia Tributaria...

    var %lrecaudador = $line(@spersonajes,$fline(@spersonajes,11 $+ $chr(32) $+ *,1))
    if (%lrecaudador) {

      ;fue EMBRUJADO el Recaudador?
      if (%sciudadelas.v.embrujado == 11) { var %jrecaudador = %sciudadelas.v.bruja }
      else { var %jrecaudador = $gettok(%lrecaudador,3,32) }

      if ( (%jrecaudador != K) && (%jrecaudador != DU) && (%jrecaudador != DD) && (%jrecaudador != %n) ) {

        if (%sciudadelas.v.construida) {

          unset %sciudadelas.v.construida

          ;quitamos una moneda al que ha construido y se la apuntamos al recaudador
          if ( $oro(%n) ) {

            oro %n -1
            oro %jrecaudador +1
            status %n
            status %jrecaudador

            sciudadelas.msg sciudadelasC* TX %n %jrecaudador

          }
        }

      }
    }

    ;antes de informar de fin de turno, miramos a ver si el que ha jugado era el embrujado
    ;en cuyo caso, no enviamos fin de turno, sino inicio de semiturno de bruja...
    ;si era el embrujado, ¡miramos a ver si el ET lo envia él o la bruja!
    if ( ($3 == %sciudadelas.v.embrujado) && ( %n != %sciudadelas.v.bruja ) ) {

      sciudadelas.msge $damesocket(%sciudadelas.v.bruja) STB $3 %sciudadelas.v.bruja
      sciudadelas.msg $damesocket(%sciudadelas.v.bruja) STB $3 %sciudadelas.v.bruja 2

    }
    else {

      sciudadelas.msg sciudadelasC* ET $3

      ;si ha jugado el "último de la lista", entonces iniciamos nueva ronda de selección de personajes
      ;previa comprobación de distritos construidos, ¡no vaya a ser que la partida haya acabado!
      ;nótese que, si el último personaje está descartado, debemos subir en la
      ;lista hasta encontrar al personaje que realmente ha jugado el último, eso lo hace $ultimo

      if ($3 == $ultimo) {

        var %ganador = $elige_ganador
        if (%ganador) { 

          ;se acabó la partida

          ;borramos variables temporales del servidor
          unset %sciudadelas.v.*

          ;informamos de final de partida
          sciudadelas.msg sciudadelasC* EG %ganador

        }
        else {

          ;al acabar la ronda, borramos variables de Bruja
          unset %sciudadelas.v.bruja 
          unset %sciudadelas.v.embrujado

          ;también limpiamos variable del recaudador...
          unset %sciudadelas.v.construida

          elige_personaje

        }

      }
      else {

        var %p = $3

        ;ahora tengo que averiguar en qué línea está, incrementar el valor de la línea y sacar el nuevo personaje

        var %c = $fline(@spersonajes, $3 $+ $chr(32) $+ * ,1)
        inc %c
        var %p = $gettok( $line(@spersonajes,%c) ,1,32)

        juega_personaje %p 

      }
    }
    return

  }

  ;si llegamos aquí, el cliente no sabe lo que está escribiendo
  ;¿deberíamos desconectarle?

}

;$ultimo -> devuelve el número del último jugador no descartado o asesinado que hay en el juego
alias ultimo {

  var %l = $line(@spersonajes,0) 

  :calculaid

  var %linea = $line(@spersonajes, %l )
  var %ultimo = $gettok( %linea ,1,32)
  var %status = $gettok(%linea,3,32)

  if ( (%status == DD) || (%status == K) || (%status == DU) ) {
    var %l = $calc(%l - 1)
    goto calculaid
  }

  return %ultimo

}

alias elige_personaje {

  ;si el rey está muerto, este es el momento de asignarle la corona que no ha podido recibir en su turno
  var %rey_linea = $line( @spersonajes , $fline(@spersonajes,4 $+ $chr(32) $+ *,1) )
  if ($gettok(%rey_linea,3,32) == K) { corona $gettok(%rey_linea,4,32) }

  ;Obtenemos corona
  var %corona = $corona

  ;enviamos mensaje de turno nuevo, el parámetro es la nueva corona
  sciudadelas.msg sciudadelasC* NT %corona

  ;dejamos personajes a 0 para volver a repartirlos
  reset_personajes

  ;descartamos lo que haya que descartar
  descarta_bocarriba
  descarta_bocabajo

  ;mensaje de selección de personaje al jugador con la corona y vuelta a empezar :D
  var %s = $damesocket(%corona)

  sciudadelas.msg %s P %corona $personajes
  sciudadelas.msge %s P %corona

}

;juega_personaje <numeropersonaje> envía orden de juego o mensaje según el personaje pueda jugar o no,
;si no puede jugar, pasa al siguiente. Cuando llega al final invoca elige_personaje.
;De paso hace la trasferencia de dinero del robado al ladron, paga al mercader, al abad y gestiona parte de la reina.
alias juega_personaje {

  var %p = $1
  var %c = $fline(@spersonajes, %p $+ $chr(32) $+ * ,1)

  :inicio
  var %p = $gettok( $line(@spersonajes,%c) ,1,32)
  var %j = $gettok( $line(@spersonajes,%c) ,3,32 ) , %conectado = $fline(@sjugadores,%j $+ $chr(32) $+ *,1)
  var %r = $gettok( $line(@spersonajes,%c) ,4,32 )

  if (%j == DD) { sciudadelas.msg sciudadelasC* ET %p DD | inc %c }
  else {
    if (%j == DU) { sciudadelas.msg sciudadelasC* ET %p DU | inc %c }
    else {

      if (%j == K) {
        ;si tiene el Hospital (id 73) construido, le damos su semiturno
        if ( $maravillas(%r,0,73)) {
          var %s = $damesocket(%r)

          ;memorizamos quién está jugando, por si el tio desconecta en su puto turno
          ;y tenemos que ser conscientes de ello para saltar al siguiente
          %sciudadelas.v.turno = %p %r

          sciudadelas.msge %s STD %p %r
          ;el parámetro con valor "3" es el que el cliente usa normalmente
          ;para saber si está en el primer o segundo semiturno de la bruja
          ;le doy el valor "3" para evitar confusiones...
          sciudadelas.msg %s STD %p %r 3
          return
        }
        else { sciudadelas.msg sciudadelasC* ET %p K | inc %c }
      }

      else {
        if (!%conectado) { sciudadelas.msg sciudadelasC* ET %p DC | inc %c }
        else {

          ;si es el Rey, le damos la corona
          if (%p == 4) { corona %j }

          if (%r) { 

            ;si han robado al personaje, averiguo quién y modifico tesoro de jugador ladrón y jugador víctima

            ;se ha usado la habilidad del ladrón para robar a otro EMBRUJANDO al ladrón?
            if (%sciudadelas.v.embrujado == 2) { var %ladron = %sciudadelas.v.bruja }
            else { var %ladron = $gettok( $line(@spersonajes,2) ,3,32) }

            var %orovictima = $oro(%j)
            oro %ladron + %orovictima
            oro %j - %orovictima
            status %ladron
            status %j

          }

          ;damos una moneda al Mercader
          if (%p == 6) {

            ;fue EMBRUJADO el mercader?
            if (%sciudadelas.v.embrujado == 6) { var %mercader = %sciudadelas.v.bruja }
            else { var %mercader = $gettok( $line(@spersonajes,6) ,3,32) }

            oro %mercader +1
            status %mercader

          }

          ;si es la Reina, miramos a ver quién es la Corona y si está vivo
          if (%p == 9) {

            ;fue EMBRUJADA la Reina?
            if (%sciudadelas.v.embrujado == 9) { var %jugadorreina = %sciudadelas.v.bruja }
            else { var %jugadorreina = %j }

            var %corona = $corona
            ;si el tio que tiene la corona está muerto, la reina sólo cobrará al acabar el turno, y eso no lo miramos aquí :)
            ;sino en la zona de ET
            var %ncorona = $fline(@sjugadores,%corona $+ $chr(32) $+ *,1)
            var %muerto = $gettok($line(@spersonajes, %ncorona) ,3,32)
            if (%muerto != K) {

              var %nprevio = $calc(%ncorona - 1) , %nsiguiente = $calc(%ncorona + 1)

              ;si nprevio vale 0, le damos el valor de la última línea (nuestro registro no es circular, la mesa sí)
              if ( %nprevio == 0 ) { var %nprevio = $line(@sjugadores,0) }
              ;si nsiguiente vale más que jugadores existentes, le damos valor 1
              if ( %nsiguiente > $line(@sjugadores,0) ) { var %nsiguiente = 1 }

              var %nreina = $fline(@sjugadores,%jugadorreina $+ $chr(32) $+ *,1)
              if ( (%nreina == %nprevio) || (%nreina == %nsiguiente) ) {

                oro %jugadorreina +3
                status %jugadorreina

                sciudadelas.msg sciudadelasC* QG %jugadorreina

              }

            }

          }

          ;el más rico paga una moneda al Abad
          if (%p == 14) {

            ;fue EMBRUJADO el Abad?
            if (%sciudadelas.v.embrujado == 14) { var %jugadorabad = %sciudadelas.v.bruja }
            else { var %jugadorabad = %j }

            var %dineroabad = $oro(%jugadorabad)

            var %control = 0 , %total = $line(@sjugadores,0), %maximo = %dineroabad

            while (%control < %total) {

              inc %control
              var %jugador = $line(@sjugadores,%control), %nombre = $gettok(%jugador,1,32), %dinero = $gettok(%jugador,4,32)
              if (%nombre == %jugadorabad) { continue }
              else {
                if (%dinero > %maximo) {

                  var %deudor = %nombre , %maximo = %dinero

                }
                ;si hay empate, no paga nadie y dejamos de mirar
                else {

                  if (%dinero == %maximo) {

                    unset %deudor | unset %maximo | break  

                  }
                  else { }

                }
              }
            }

            if ( (%deudor) && (%deudor != %jugadorabad) ) {

              ;restamos 1 a víctima, sumamos uno a abad, actualizamos info e informamos
              oro %jugadorabad +1
              oro %deudor -1
              status %jugadorabad
              status %deudor

              sciudadelas.msg sciudadelasC* AB %deudor %jugadorabad

            }

          }

          var %s = $damesocket(%j)

          ;memorizamos quién está jugando, por si el tio desconecta en su puto turno
          ;y tenemos que ser conscientes de ello para saltar al siguiente
          %sciudadelas.v.turno = %p %j

          sciudadelas.msge %s ST %p %j
          sciudadelas.msg %s ST %p %j 1
          %c = 0

        }

      }
    }
  }

  if (%c > $numtok(%sciudadelas.f.personajes,32) ) {

    ;elige_personaje 
    ;no podía ser la cosa tan sencilla...

    var %ganador = $elige_ganador
    if (%ganador) { 
      ;se acabó la partida

      ;borramos variables temporales del servidor
      unset %sciudadelas.v.*

      ;informamos de final de partida
      sciudadelas.msg sciudadelasC* EG %ganador

    }
    else {
      ;al acabar la ronda, borramos variables de Bruja
      unset %sciudadelas.v.bruja 
      unset %sciudadelas.v.embrujado

      ;también limpiamos variable del recaudador...
      unset %sciudadelas.v.construida

      elige_personaje
    }


  }
  else { 
    if (%c) { goto inicio } 
  }

}

;$calcula_puntos(jugador) devuelve los puntos actuales del jugador
alias calcula_puntos {

  var %c = 0, %total = $fline(@sdistritos, * $+ $chr(32) $+ $1,0)
  var %puntosjugador = 0

  while (%c < %total) {

    inc %c

    var %carta = $line(@sdistritos, $fline(@sdistritos, * $+ $chr(32) $+ $1,%c) )
    var %id = $gettok(%carta,1,32)
    var %puntoscarta = $gettok(%carta,3,32)
    var %construida = $gettok(%carta,4,32)
    var %color = $gettok(%carta,5,32)

    if (%construida) {

      var %colores = $addtok(%colores,%color,32) 
      inc %puntosjugador %puntoscarta

      ;MARAVILLAS que influyen en el resultado final

      ;tesoro imperial -> suma oro a puntos totales
      if (%id == 60) { inc %puntosjugador $oro($1) }

      ;universidad y puerta dragón -> cada uno suma +2 al final además de su precio de construcción
      if ( (%id == 65) || (%id == 71) ) { inc %puntosjugador 2 }

      ;fuente de los deseos -> +1 por cada maravilla de más que tengas (sin incluir la fuente)
      var %maravillas = $maravillas($1)
      if (%id == 70) { inc %puntosjugador $calc( %maravillas - 1 ) }

      ;patio de los milagros da un color extra si tienes otra maravilla
      if (%id == 58) { var %milagros = 1 }

      ;sala de mapas te da un punto extra por cada carta que tengas en la mano
      if (%id == 72) { inc %puntosjugador $cartas($1) }

      ;museo te da un punto extra por cada carta puesta debajo (pertenecientes a MU, vaya)
      if (%id == 78) { inc %puntosjugador $fline(@sdistritos, * $+ $chr(32) $+ MU ,0) }

    }

  }

  ;el patio de los milagros influye en los colores finales
  if ( (%maravillas > 1) && (%milagros) ) { var %colores = $addtok(%colores,1,32)   }

  if ($numtok(%colores,32) == 5) { inc %puntosjugador 3 }

  ;si tiene 8 distritos recibirá 4 ó 2 puntos, dependiendo de si fue el primero en construirlos o no
  if ( $distritos_construidos($1) == $calc(8 - %sciudadelas.v.tb) ) {

    if ( $gettok(%sciudadelas.v.ocho ,1,32) == $1 ) { inc %puntosjugador 4 }
    else { inc %puntosjugador 2 }

  }

  return %puntosjugador

}

;$maravillas(jugador) -> devuelve número de maravillas construidas
;si se pasa segundo argumento, devuelve la maravilla que ocupa ese puesto.
;un tio con 3 maravillas: $maravillas(jugador) -> 3 ; $maravillas(jugador,2) -> id de la segunda maravilla construida
;si pasamos como tercer argumento el id de una maravilla, nos devuelve 1 si el jugador ha construido esa maravilla:
;ejemplo $maravillas(jugador,0,61) -> devuelve 1 si jugador tiene cantera construida, 0 en caso contrario.

alias maravillas {

  var %c = 0 , %total = $fline(@sdistritos, * $+ $chr(32) $+ $1 ,0) , %maravillas = 0

  while (%c < %total) {

    inc %c

    var %carta = $line(@sdistritos, $fline(@sdistritos, * $+ $chr(32) $+ $1 ,%c) )
    var %id = $gettok(%carta,1,32)
    var %color = $gettok(%carta,5,32)
    var %construida = $gettok(%carta,4,32)

    if ((%color == 0) && (%construida)) { inc %maravillas }

    ;esto, obviamente, no está dando lo que debería dar
    if ($2 == %c) { return $gettok(%carta,1,32) }

    if ($3 == %id) {

      if (%construida) { return 1 }
      else { return 0 }

    }
  }

  if ($3) { return 0 }
  else { return %maravillas }

}

;$construida(jugador,nombrecarta) -> $construida(jugador,tienda) devolverá 1 si el jugador tiene una tienda construida.
alias construida {

  ;recorremos todos los distritos y paramos cuando encontremos uno con el nombre dado
  var %c = 0 , %total = $fline(@sdistritos, * $chr(32) $+ $1,1)
  while (%c < %total) {

    inc %c

    var %nc = $fline(@sdistritos,* $chr(32) $+ $1,%c) , %carta = @line(@sdistritos,%nc)
    var %nombre = $gettok(%carta,2,32)
    if (%nombre == $2) { return 1 }

  }

  return 0

}

;cobra_distritos <jugador> <personaje>: apunta al jugador el oro correspondiente en función de su personaje y distritos construidos
alias cobra_distritos {

  var %personaje = $2

  ;navegamos a través de todos los distritos en poder del personaje
  var %c = 0 , %total = $fline(@sdistritos,* $+ $chr(32) $+ $1,0), %cobrar = 0

  while (%c < %total) {

    inc %c

    var %distrito = $line( @sdistritos, $fline(@sdistritos, * $+ $chr(32) $+ $1 ,%c) )

    ;¿da oro al personaje en cuestión el distrito?
    if ( $gettok(%distrito,5,32) == $2 ) {

      ;¿está construido?
      if ( $gettok(%distrito,4,32) ) {
        inc %cobrar
      }

    }

  }

  ;si está construida la escuela de magia, cobra una moneda más
  if ( $maravillas($1,0,64) ) { inc %cobrar }

  if (%cobrar) {

    oro $1 + %cobrar
    status $1

    sciudadelas.msg sciudadelasC* GD $1 %cobrar

  }

}

;$distritos_construidos(jugador) -> devuelve número de distritos construidos
alias distritos_construidos {

  var %c = 0, %total = $fline(@sdistritos, * $+ $chr(32) $+ $1,0)
  var %distritos = 0

  while (%c < %total) {

    inc %c

    var %carta = $line(@sdistritos, $fline(@sdistritos, * $+ $chr(32) $+ $1,%c) )
    var %construida = $gettok(%carta,4,32)

    if (%construida) {
      inc %distritos 
    }

  }

  return %distritos

}

;$elige_ganador -> devuelve el nombre del tio con más puntos (y los puntos) si alguno de los jugadores tiene 8 distritos construidos
alias elige_ganador {

  var %c = 0 , %total = $line(@sjugadores,0) , %puntosganador = 0

  while (%c < %total) {

    inc %c

    var %lj = $line(@sjugadores,%c) , %j = $gettok(%lj,1,32) , %puntos = $gettok(%lj,2,32)

    if ($distritos_construidos(%j) == $calc(8 - %sciudadelas.v.tb) ) { var %fin = 1 }
    if ( %puntosganador < %puntos ) { %puntosganador = %puntos | var %ganador = %j }

  }

  if (%fin) { return %ganador %puntosganador }
  else { return 0 }

}

dialog personajes {
  title $texto(160)
  option dbu
  size -1 -1 170 160

  text $texto(161) ,100,10 10 190 30,wrap

  radio $texto(111),1,10 20 50 10,group
  radio $texto(140),10,70 20 50 10

  radio $texto(112),2,10 30 50 10,group
  radio $texto(142),11,70 30 50 10

  radio $texto(113),3,10 40 50 10,group
  radio $texto(144),12,70 40 50 10

  radio $texto(114),4,10 50 50 10,group
  radio $texto(146),13,70 50 50 10

  radio $texto(115),5,10 60 50 10,group
  radio $texto(148),14,70 60 50 10

  radio $texto(116),6,10 70 50 10,group
  radio $texto(150),15,70 70 50 10

  radio $texto(73),7,10 80 50 10,group
  radio $texto(152),16,70 80 50 10

  radio $texto(117),8,10 90 50 10,group
  radio $texto(154),17,70 90 50 10

  check $texto(162), 90,10 110 50 10
  radio $texto(156),9,10 120 50 10,group disable
  radio $texto(158),18,70 120 50 10, disable

  button "Ok",200,50 140 20 15,ok
}

on 1:dialog:personajes:init:0: {

  if ( %sciudadelas.f.personajes ) {
    var %c = 0, %total = $numtok(%sciudadelas.f.personajes,32)
    while (%c < %total) {
      inc %c 
      did -c personajes $gettok(%sciudadelas.f.personajes,%c,32)
    }
    if ( $istok(%sciudadelas.f.personajes,9,32) || $istok(%sciudadelas.f.personajes,18,32) ) {
      did -c personajes 90 
      did -e personajes 9,18
    }
  }
  else {
    did -c personajes 1,2,3,4,5,6,7,8 
  }

}

;al cerrar, averiguamos qué personajes están activados
on 1:dialog:personajes:close:0:{

  var %c = 0
  %sciudadelas.f.personajes = ""
  while ( %c < 18 ) {
    inc %c
    var %r = $did(personajes,%c).state
    if (%r) { %sciudadelas.f.personajes = $addtok(%sciudadelas.f.personajes,%c,32) }
  }

  ;reseteamos nuestra ventana @spersonajes!
  reset_personajes

}

on 1:dialog:personajes:sclick:90:{

  if ( $did(personajes,90).state ) {
    did -e personajes 9,18 
    did -c personajes 9
  }
  else { did -bu personajes 9,18 }

}

on 1:dialog:jugar:sclick:*:{

  if ($did == 13) { dialog -m personajes personajes }
  if ($did == 16) { did -ob jugar 16 1 0 $texto(14) | did -e jugar 22 | crea_partida }
  if ($did == 17) {

    ;siempre y cuando haya partida creada, la iniciamos
    if ( ( $sock(sciudadelasC*,0) > 0 ) && ( $sock(sciudadelasC*,0) < 9 ) ) {
      did -b jugar 13,17 | inicia_partida  
    }

  }

  ;apagar partida en servidor
  if ($did == 22) {

    if ((%cciudadelas.f.listados) && ($sock(listados))) { sockwrite -n listados CP %sciudadelas.f.partida %sciudadelas.f.puerto }
    unset %sciudadelas.v.*
    sockclose sciudadelas*
    did -oe jugar 16 1 $texto(12)
    did -b jugar 17,22
    did -e jugar 13,1,2,3,7
    did -o jugar 7 1 $texto(8) 

  }

}

;oro pepito +3 -> suma 3 monedas a pepito
;$oro(pepito) -> nos devuelve el número de monedas de pepito
alias oro {
  if (!$2) { return $edita_personaje($1,4) }
  else {
    edita_personaje $1 4 $2-
  }
}

;cartas pepito +3 -> suma 3 cartas a pepito
;$cartas(pepito) -> nos devuelve el número de cartas de pepito
alias cartas {
  if (!$2) { return $edita_personaje($1,3) }
  else {
    edita_personaje $1 3 $2-
  }
}

;edita_personaje <nombrejugador> <campo> <modificación> -> actualiza oro de un jugador
;función genérica para obtener el valor de un campo de un personaje o modificarlo
;campos: 3->cartas 4->oro
alias edita_personaje {

  if ($1) {

    var %njugador = $fline(@sjugadores,$1 $+ $chr(32) $+ *,1) , %jugador = $line(@sjugadores,%njugador)
    var %valor = $gettok(%jugador, $2 ,32)

    if (!$3) { return %valor }
    else {

      var %jugador = $puttok(%jugador, $calc( %valor $3- ) , $2 ,32)
      rline @sjugadores %njugador %jugador

      var %jugador = $puttok(%jugador, $calcula_puntos($1) , 2,32)
      rline @sjugadores %njugador %jugador

    }

  }

}

;status <nombrejugador> -> envia a todos los jugadores un mensaje actualizando status (J)
;ej: status pepito
alias status {

  if ($1) {
    var %jugador = $line(@sjugadores,$fline(@sjugadores,$1 $+ $chr(32) $+ *,1))
    sciudadelas.msg sciudadelasC* J %jugador
  }

}

;lista_mazo -> devuelve un listado de los ids disponibles en el mazo
;esta función es para la maravilla del Faro

alias lista_mazo {

  ;obtengo número de cartas asignadas a M (mazo)
  var %x = 0 , %total = $fline(@sdistritos,* $+ M,0), %cartas = "", %tipos = ""
  while (%x < %total) {

    inc %x
    var %carta = $line(@sdistritos, $fline(@sdistritos,* $+ M,%x) )

    ;no tiene mucha utilidad enviar cartas repetidas (pej. 3 tiendas y cosas así),
    ;enviamos el primer id que encontremos para cada tipo de carta y el número 
    ;de cartas iguales que hay en el mazo

    var %tipo = $gettok(%carta,2,32)
    if ( !$istok(%tipos,%tipo,32) ) {
      var %tipos = %tipos %tipo
      var %id = $gettok(%carta,1,32)
      var %cartas = %cartas %id
    }
    else {

      ;tipo repetido, anotamos en %cartas
      ;pej. si el primer id de tienda en el mazo
      ;barajado es 12 y hay 4 tiendas, tendremos 12:4

      ;La anotación se hace sólo la primera vez que se repite el tipo.
      ;Averiguamos primer id libre con ese tipo y luego lo buscamos en %cartas
      ;si no lo encontramos, tiene que ser porque ya le hemos pegado la info, paramos.

      var %primer_id = $gettok($line(@sdistritos, $fline(@sdistritos,* $+ $chr(32) $+ %tipo $+ * $+ $chr(32) $+ M,1) ) ,1,32)
      if ( $istok(%cartas,%primer_id,32) ) {
        var %cadena_vieja = %primer_id
        var %cadena_nueva = %primer_id $+ : $+ $fline(@sdistritos,* $+ $chr(32) $+ %tipo $+ * $+ $chr(32) $+ M,0)
        ;$reptok(text,token,new,N,C)
        var %cartas = $reptok(%cartas, %cadena_vieja , %cadena_nueva , 1, 32 )
      }
    }

  }

  return %cartas

}

;todeck_museo -> devuelve al mazo todas las cartas que estuvieran en el museo
;llamamos esta función cuando destruyen el museo
alias todeck_museo {

  while ( $fline(@sdistritos, * $+ $chr(32) $+ MU ,1) ) {
    var %n = $fline(@sdistritos, * $+ $chr(32) $+ MU ,1) , %id = $gettok($line(@sdistritos,%n),1,32)
    todeck %id
  }

}
