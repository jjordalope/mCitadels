;Ciudadelas cliente
;GNU 2004 kat@fiade.com

;control de versiones
alias cversion { return beta4  }

on 1:start:{

  ;imponemos ventana principal maximizada
  showmirc -x

  window -hl @mensajes
  loadbuf @mensajes ciudadelas/ $+ %cciudadelas.f.msgs

  echo -s mCitadels $cversion 12kat@fiade.com

  titlebar mCitadels

  carga_datos

  window -nh "Status Window"

  ;medimos máxima extensión de ventana para dibujar sin maximizar a gusto
  ;sólo dibujando sin maximizar podremos meter un editbox en las ventanas gráficas
  ;de paso controlamos resolución... (necesitamos un mínimo de 1024x768)
  mide_ventana

  if (%cciudadelas.f.w > 1000) { dibuja_inicio }

}

on 1:exit: { unset %cciudadelas.v.* }

menu status { 

  opciones: dibuja_inicio 

}

alias carga_datos {

  window -c @distritos
  window -c @cartas
  window -c @jugadores
  window -c @cartaspersonajes
  window -c @botones
  window -c @edit

  window -hl @distritos
  window -hl @cartas
  window -hl @jugadores
  window -hl @botones

  loadbuf -e @distritos ciudadelas/distritos.txt

  unset %cciudadelas.v.*
  unset %cciudadelas.g.*
  unset %cciudadelas.f.personajes

}


;TABLERO

alias dibuja_mesa {

  ;borramos ventanas y reseteamos variables, por si acaso
  window -c $ventana(mesa)

  window -pbk[0] +d $ventana(mesa) 1 1 %cciudadelas.f.w %cciudadelas.f.w 

  drawfill -r $ventana(mesa) 32768 1 1 1

  drawpic $ventana(mesa) 820 25 ciudadelas/ciudadelas.jpg
  drawpic $ventana(mesa) 820 390 ciudadelas/ciudadelas_personaje.jpg

}

;MENÚ MESA
menu @* {

  mouse: { if ($ventana(mesa) == $active) { dentrocarta $mouse.x $mouse.y } }

  sclick: {

    if ($ventana(mesa) == $active) {

      var %id = $sel_carta($mouse.x, $mouse.y)
      if ( %id ) {

        ;si es un distrito
        if (%id isnum) {

          ;destruir distrito usando Powderhouse
          if (%cciudadelas.v.powderhouse) {

            edita_boton PD D2
            unset %cciudadelas.v.powderhouse
            sockwrite -n cciudadelas PD %id

          }

          ;Destruir distrito con el Condotiero
          if (%cciudadelas.v.destruir_distrito) {

            ;si es El Torreón, no puede ser destruido
            if (%id == 59) { msg $texto(15) }
            else {

              ;obtenemos nombre del jugador víctima para futura referencia
              var %f = $gettok( $line(@cartas, $fline(@cartas,%id $+ $chr(32) $+ *,1) ) ,2,32)
              var %j = $gettok( $line(@jugadores,%f) ,1,32)

              ;comprobamos que nos da el oro
              var %oro = $gettok( $line(@jugadores, $fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1) ) ,4,32)
              var %precio = $calc( $gettok( $line(@distritos, $fline(@distritos,%id $+ $chr(32) $+ *,1) ) ,3,32) - 1 )

              ;si tiene construida la muralla nos va a costar más caro...
              if ( $maravilla_construida(63,%j) ) { inc %precio }

              ;si el distrito está ornamentado, aumentamos precio
              if ( $gettok($line(@cartas,$fline(@cartas, %id $+ $chr(32) $+ *,1)) ,6,32) ) { inc %precio }

              if ( %precio > %oro ) { msg $texto(16) }
              else {

                ;comprobamos que no es obispo vivo: obtenemos fila de la carta, de la fila sacamos jugador y miramos %cciudadelas.v.obispo a ver si es el mismo
                if (%j == %cciudadelas.v.obispo) { msg $texto(17) }
                else {

                  ;puede no ser el obispo pero ¿y la bruja con la habilidad del mismo?
                  if ( (%j == %cciudadelas.v.bruja) && (%cciudadelas.v.embrujado == 5) ) { msg $texto(17) }
                  else {

                    ;comprobamos que no tiene ya construidos 8 distritos
                    if ( $construidos(%j) == $calc(8 - %cciudadelas.g.tb) ) { msg $texto(18, $calc(8 - %cciudadelas.g.tb) ) }
                    else {

                      edita_boton KD D2
                      unset %cciudadelas.v.destruir_distrito
                      sockwrite -n cciudadelas KD %id

                    }
                  }
                }
              }
            }
          }

          ;Ornamentar (sic) distritos con el Artista
          if ( (%cciudadelas.v.artista) && (%cciudadelas.v.artista < 4) ) {

            ;puede pagar?
            var %oro = $gettok($line(@jugadores,$fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1)) ,4,32)
            if (!%oro) { msg $texto(190) | unset %cciudadelas.v.artista | edita_boton AR D2 }
            else {

              ;el distrito es suyo?
              var %ncarta = $fline(@cartas, %id $+ $chr(32) $+ *,1) , %carta = $line(@cartas,%ncarta)
              var %filacarta = $gettok( %carta ,2,32)
              var %filajugador = $fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1)
              if (%filacarta != %filajugador) { msg $texto(191) }
              else {

                ;está ya ornamentado?
                var %ornamentado = $gettok(%carta,6,32)
                if (%ornamentado) { msg $texto(192) }
                else {

                  ;ornamentamos pues
                  ;controlamos que sólo se ornamenten dos distritos por turno
                  inc %cciudadelas.v.artista
                  if (%cciudadelas.v.artista == 4) { edita_boton AR D2 }
                  else {
                    sockwrite -n cciudadelas AR %id
                  }

                }

              }

            }

          }

          ;Cambiar distritos con el Diplomático
          if (%cciudadelas.v.diplomatico) {

            ;si es El Torreón, no puede ser intercambiado
            if (%id == 59) { msg $texto(15) }
            else {
              var %nc = $fline(@cartas,%id $+ $chr(32) $+ *,1) , %carta = $line(@cartas,%nc)
              ;si la carta estaba seleccionada, la deseleccionamos
              if ( $gettok(%carta,5,32) ) { rline @cartas %nc $puttok(%carta,0,5,32) }
              ;seleccionamos carta
              else {
                rline @cartas %nc $puttok(%carta,DP,5,32)

                ;miramos a ver si ya hay dos cartas seleccionadas para hacer el cambio
                var %total = $fline(@cartas, * $+ DP $+ * , 0)
                echo total: %total
                if (%total == 2) {

                  var %carta1 = $line(@cartas, $fline(@cartas, * $+ DP $+ *,1))
                  var %carta2 = $line(@cartas, $fline(@cartas, * $+ DP $+ *,2))

                  var %nombrecarta1 = $gettok(%carta1,2,32)
                  var %nombrecarta2 = $gettok(%carta2,2,32)

                  var %owner1 = $gettok( $line(@jugadores,$gettok(%carta1,2,32)) ,1,32)
                  var %owner2 = $gettok( $line(@jugadores,$gettok(%carta2,2,32)) ,1,32)

                  ;comprobamos que una de las cartas es nuestra y que la otra NO lo es,
                  if ( ( (%owner1 == %cciudadelas.f.nombre) && (%owner2 != %cciudadelas.f.nombre) ) || ( (%owner1 != %cciudadelas.f.nombre) && (%owner2 == %cciudadelas.f.nombre) ) ) {

                    ;comprobamos que la víctima no es el obispo vivo
                    if ( (%owner1 == %cciudadelas.v.obispo) || (%owner2 == %cciudadelas.v.obispo) ) { msg $texto(174) | rline @cartas %nc $puttok(%carta,0,5,32) }
                    else { 

                      ;comprobamos que la víctima no es la bruja con la habilidad del obispo
                      if ( ((%owner1 == %cciudadelas.v.bruja) || (%owner2 == %cciudadelas.v.bruja)) && (%cciudadelas.v.embrujado == 5) ) { msg $texto(174) | rline @cartas %nc $puttok(%carta,0,5,32) }
                      else {

                        ;si alguno de los involucrados ha cerrado, abortamos
                        if ( ( $construidos(%owner1) == $calc(8 - %cciudadelas.g.tb) )  || ( $construidos(%owner2) == $calc(8 - %cciudadelas.g.tb) ) ) { msg $texto(177, $calc(8 - %cciudadelas.g.tb) ) }
                        else {

                          ;si como resultado del cambio, alguno de los implicados repite distritos sin tener cantera, abortamos
                          if ( ( !$maravilla_construida(61,%owner1) ) && ($distrito_construido(%nombrecarta2,%owner1) ) || ( !$maravilla_construida(61,%owner2) ) && ($distrito_construido(%nombrecarta1,%owner2) ) ) { msg $texto(178) }
                          else {

                            ;si hemos de pagar, comprobamos que tenemos el dinero necesario
                            var %id1 = $gettok(%carta1,1,32)
                            var %id2 = $gettok(%carta2,1,32)
                            var %precio1 = $gettok( $line(@distritos,$fline(@distritos,%id1 $+ $chr(32) $+ *,1)) ,3,32)
                            var %precio2 = $gettok( $line(@distritos,$fline(@distritos,%id2 $+ $chr(32) $+ *,1)) ,3,32)

                            var %dinero = $gettok( $line(@jugadores,$fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1)) ,4,32)

                            if (%owner1 == %cciudadelas.f.nombre) {

                              var %dif = $calc(%precio2 - %precio1)

                              ;si tiene construida la muralla nos va a costar más caro...
                              if ( $maravilla_construida(63,%owner2) ) { inc %dif }

                              ;si el distrito está ornamentado, aumentamos precio
                              if ( $gettok(%carta2 ,6,32) ) { inc %dif }

                              if (%dif > %dinero) { msg $texto(175) }
                              else { sockwrite -n cciudadelas DP %id1 %id2 | edita_boton DP D2 | deselecciona | unset %cciudadelas.v.diplomatico }

                            }
                            else {

                              var %dif = $calc(%precio1 - %precio2)

                              ;si tiene construida la muralla nos va a costar más caro...
                              if ( $maravilla_construida(63,%owner1) ) { inc %dif }

                              ;si el distrito está ornamentado, aumentamos precio
                              if ( $gettok(%carta1 ,6,32) ) { inc %dif }

                              if (%dif > %dinero) { msg $texto(175) | rline @cartas %nc $puttok(%carta,0,5,32) }
                              else { sockwrite -n cciudadelas DP %id2 %id1 | edita_boton DP D2 | deselecciona | unset %cciudadelas.v.diplomatico  }

                            }
                          }
                        }
                      }
                    }

                  }
                  else { msg $texto(173) | rline @cartas %nc $puttok(%carta,0,5,32) }

                }
              }

            }

          }

        }

        ;si es un jugador
        if (%id !isnum) {

          ;Mago
          if (%cciudadelas.v.cambiar_cartas) { 
            sockwrite -n cciudadelas C %id
            edita_boton C D2
            unset %cciudadelas.v.cambiar_cartas
          }

          ;Hechicero
          if (%cciudadelas.v.hechicero) {
            sockwrite -n cciudadelas W %id
            edita_boton W D2
            unset %cciudadelas.v.hechicero
          }

          ;Emperador
          if (%cciudadelas.v.emperador) {

            ;comprobamos que no se da la corona a sí mismo
            if (%id == %cciudadelas.f.nombre) { msg $texto(186) }
            else {

              ;comprobamos que no se la da al que ya la tiene
              var %c = 0 , %total = $line(@jugadores,0)
              while (%c < %total) {
                inc %c
                var %j = $line(@jugadores,%c)
                if $gettok(%j,5,32) { var %corona = $gettok(%j,1,32) }
              }

              if (%id == %corona) { msg $texto(187) }
              else { 

                sockwrite -n cciudadelas EM %id
                edita_boton EM D2
                unset %cciudadelas.v.emperador
                ;no dejamos terminar turno hasta que le hayan pagado o enviado mensaje de "no pago" (EMN)
                edita_boton ET D2

              }
            }

          }

        }

      } 

      var %id = $sel_boton($mouse.x,$mouse.y)
      if ( %id ) {

        if ( %id == GG ) { sockwrite -n cciudadelas GG | edita_boton GG D2 | edita_boton GC D2 }

        if ( %id == ET ) {
          ;anulamos ventanas y opciones previas
          window -c $ventana(personajes)
          if (%cciudadelas.v.cambiar_cartas) {
            borra_boton_ok
            borra_cuadro
            unset %cciudadelas.v.cambiar_cartas
          }
          borra_botones
          sockwrite -n cciudadelas ET $gettok(%cciudadelas.v.turno,1,32) 
        } 

        if ( %id == GC ) { sockwrite -n cciudadelas GC |  edita_boton GG D2 | edita_boton GC D2 }
        if ( %id == K ) { edita_boton K A | dibuja_personajes 2 | cuadro_personajes $texto(34) $texto(217) }
        if ( %id == R ) { edita_boton R A | dibuja_personajes 3 | cuadro_personajes $texto(35) $texto(218) }
        if ( %id == GD ) { sockwrite -n cciudadelas GD $gettok(%cciudadelas.v.turno,1,32) | edita_boton GD D2 | %cciudadelas.v.gd = 1 }
        if ( %id == GEC ) { sockwrite -n cciudadelas GEC | edita_boton GEC D2 }
        if ( %id == C ) { edita_boton C A | %cciudadelas.v.cambiar_cartas = 1 | cuadro_cambiarcartas | boton_ok }
        if ( %id == KD ) { edita_boton KD A | %cciudadelas.v.destruir_distrito = 1 } 

        if (%id == NC) { sockwrite -n cciudadelas NC | edita_boton NC D2 | edita_boton NG D2 }
        if (%id == NG) { sockwrite -n cciudadelas NG | edita_boton NC D2 | edita_boton NG D2 }
        if (%id == W) { edita_boton W A | %cciudadelas.v.hechicero = 1 }
        if (%id == DP) { edita_boton DP A | %cciudadelas.v.diplomatico = 1 }
        if (%id == EM) { edita_boton EM A | %cciudadelas.v.emperador = 1 }
        if (%id == AR) { edita_boton AR A | %cciudadelas.v.artista = 1 }
        if (%id == BR) { edita_boton BR A | dibuja_personajes 4 | cuadro_personajes $texto(194) $texto(219) }

        if ( %id == F ) {
          edita_boton F D2
          ;¿tenemos 2 monedas?
          if ($gettok( $line(@jugadores,$fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1)) ,4,32) > 1) {
            sockwrite -n cciudadelas F | %cciudadelas.v.fabrica = 1
          }
          else { msg $texto(19) }
        }

        if ( %id == L ) { edita_boton L A | %cciudadelas.v.laboratorio = 1 | cuadro_laboratorio | window -a $ventana(mano)  }
        if ( %id == CY ) { sockwrite -n cciudadelas CY | edita_boton CY D2 }
        if ( %id == PD ) { edita_boton PD A | %cciudadelas.v.powderhouse = 1 }
        if ( %id == MU ) { edita_boton MU A | %cciudadelas.v.museo = 1 | cuadro_museo | window -a $ventana(mano) }
        if ( %id == TB ) { sockwrite -n cciudadelas TB | edita_boton TB D2 }

      }
    }
  }

}

;quita la marca de seleccion a todas las cartas de la mesa
alias deselecciona {

  var %c = 0 , %total = $line(@cartas,0)

  while (%c < %total) {

    inc %c

    var %carta = $line(@cartas,%c)
    rline @cartas %c $puttok(%carta ,0,5,32)
    drawrect -r $ventana(mesa) 1 2 $coordenadas( $gettok(%carta,3,32) , $gettok(%carta,2,32) ) 65 105 

  }

}

;dibujamos cuadro en personajes y encuadramos dentro el texto pasado como argumento
;de modo que el primer parámetro es el título
alias cuadro_personajes {

  drawrect -rdf $ventana(personajes) 11595006 1 850 30 130 210 30 30
  drawtext $ventana(personajes) 1 arial 18 870 40  $1
  encuadra $ventana(personajes) 860 61 120 11 arial 11 $2-

}

;dibujamos un cuadro con información y un botón en @mano
alias cuadro_cambiarcartas {

  drawrect -rdf $ventana(mano) 11595006 1 820 25 130 210 30 30
  drawtext $ventana(mano) 1 arial 18 826 35  $texto(20)
  encuadra $ventana(mano) 830 56 120 12 arial 12 $texto(21)

}

;dibujamos cuadro con información de uso del Laboratorio en @mano
alias cuadro_laboratorio {

  drawrect -rdf $ventana(mano) 11595006 1 820 25 130 210 30 30
  drawtext $ventana(mano) 1 arial 18 826 35  $texto(22)
  encuadra $ventana(mano) 830 56 120 12 arial 12 $texto(23)

}

;dibujamo cuadro con información de uso del Museo en @mano
alias cuadro_museo {

  drawrect -rdf $ventana(mano) 11595006 1 820 25 130 210 30 30
  drawtext $ventana(mano) 1 arial 18 826 35  $texto(228)
  encuadra $ventana(mano) 830 56 120 12 arial 12 $texto(252)

}

alias borra_cuadro {

  drawrect -rdf $ventana(mano) 32768 1 820 25 130 210 30 30

}

alias boton_ok {

  drawrect -rf $ventana(mano) 15324629 1 820 390 130 40 
  drawrect -r $ventana(mano) 7209070 3 820 390 130 40 
  drawtext -o $ventana(mano) 1 Arial 14 870 400 OK

}

alias borra_boton_ok {

  drawrect -rf $ventana(mano) 32768 1 820 390 130 40 

}

;$dibujo(id)
;devuelve el nombre del archivo de dibujo de un determinado id

alias dibujo {

  return $gettok($line(@distritos,$fline(@distritos, $1 $+ * ,1,1)),6,32)

}

;dentrocarta x y
;esta es la rutina que "ilumina" las cartas al pasar sobre ellas el ratón.
;un tercer parámetro nos indica que trabajamos con las ventanas @mano y @cartasmano
;o bien con @hechicero y @cartashechicero

alias dentrocarta {

  ;boton_ok o similar
  if ( ($3) && (%cciudadelas.v.cambiar_cartas) ) || ( ($3) && (%cciudadelas.v.pagar) ) {

    if ( $inrect($1,$2,820,390,130,40) ) { drawrect -r $ventana(mano) 33023 3 820 390 130 40 }
    else { drawrect -r $ventana(mano) 7209070 3 820 390 130 40 }

  }

  ;en @mano no tiene sentido que miremos mazo y jugadores...
  if ( (!$3) || ($3 != mazo) ) {

    ;¿encima de un boton?
    dentro_boton $1-

    ;¿estamos dentro de un jugador?
    var %jugadores = $line(@jugadores,0) , %c = 0
    var %x = 25

    while (%c < %jugadores) {

      inc %c

      var %jugador = $line(@jugadores,%c), %desconectado = $gettok(%jugador,7,32) , %nombre = $gettok(%jugador,1,32)
      var %y = $calc( ( (%c - 1)  * 105 ) + ( (%c - 1) * 6) + 25 )

      if ( $inrect($1,$2,%x,%y,130,105) ) {

        if ((!%desconectado) && (%nombre != %cciudadelas.f.nombre)) { drawrect -rd $ventana(mesa) 33023 1 %x %y 130 105 30 30 }

      }
      else { drawrect -rd $ventana(mesa) 1 1 %x %y 130 105 30 30 }
    }

  }

  ;¿dentro de una carta?

  if ($3) {

    if ($3 == mano) { var %ventana = $ventana(mano) , %ventana_control = @cartasmano }
    if ($3 == hechicero) { var %ventana = $ventana(hechicero) , %ventana_control = @cartashechicero }
    var %w = 130 , %h = 210 
    if ($3 == mazo) { 
      var %ventana = $ventana(mazo) , %ventana_control = @cartas_mazo 
      var %w = 65 , %h = 105
    }

  }
  else { var %ventana = $ventana(mesa) , %ventana_control = @cartas , %w = 65 , %h = 105 }

  var %cartas = $line(%ventana_control,0), %c = 0

  while (%c < %cartas) {

    inc %c

    var %carta = $line(%ventana_control,%c)
    var %id = $gettok(%carta,1,32)
    var %coordenadas = $coordenadas( $gettok(%carta,3,32) , $gettok(%carta,2,32) , $3 )
    var %x = $gettok(%coordenadas,1,32)
    var %y = $gettok(%coordenadas,2,32)
    var %iluminada = $gettok(%carta,4,32)
    var %seleccionada = $gettok(%carta,5,32)
    var %ornamentada = $gettok(%carta,6,32)

    if ( $inrect($1,$2,%x,%y,%w,%h) ) { 

      if ( !%iluminada  ) {

        ;si estamos descartando, sólo iluminaremos las cartas susceptibles de ser descartadas...
        if ($3) {

          if (%cciudadelas.v.descartar) {

            if ($istok(%cciudadelas.v.descartar,%id,32)) {

              ;dibujo rectángulo naranja
              drawrect -r %ventana 33023 2 %x %y %w %h 
              ;marco en @ventana_control para saber que ésta está iluminada y hay que redibujar al salir...
              rline %ventana_control %c $puttok(%carta,1,4,32)

            }

          }
          else {

            drawrect -r %ventana 33023 2 %x %y %w %h 
            rline %ventana_control %c $puttok(%carta,1,4,32)

          }

        }
        else {

          drawrect -r %ventana 33023 2 %x %y %w %h 
          rline %ventana_control %c $puttok(%carta,1,4,32)

        }


        ;dibujo carta grande
        if ( (!$3) || ($3 == mazo) ) {
          drawpic -c %ventana 820 25 ciudadelas/ $+ $replace($dibujo(%id),.,2.) 

          ;si estamos en @MAZO, indicamos cartas similares que quedan libres
          if (%cciudadelas.v.listaIDS) {
            cuadradito %id
          }

          ;si hay cartas bajo el MUSEO y estamos encima suyo, dibujamos número de las mismas
          if (%id == 78) {
            ;var %bajo_museo = $fline(@sdistritos, * $+ $chr(32) $+ MU ,0) 
            if (%cciudadelas.g.bajo_museo) {
              drawrect -rf $ventana(mesa) 11595006 1 925 30 20 20
              drawtext $ventana(mesa) 1 arial 20 929 28 %cciudadelas.g.bajo_museo
            }
          }

        }

        ;si es maravilla, dibujamos cuadro con el texto
        var %texto = $gettok( $line( @distritos , $fline(@distritos, %id $+ * ,1) ) , 7- , 32)
        if ( %texto ) && (!%iluminada) {

          drawrect -rdf %ventana 15324629 1 820 250 130 125 30 30
          drawrect -rd %ventana 7209070 1 820 250 130 125 30 30
          ;parece que el mirc no tiene un sistema para hacer wrap al texto, más trabajo :/
          encuadra %ventana 826 253 120 10 arial 10 %texto
          rline %ventana_control %c $puttok(%carta,1,4,32)

        }

      }
    }

    else { 

      if ( %iluminada ) {

        if ( ($3) && ($3 != mazo) ) { var %dibujo = $replace( $dibujo($gettok(%carta,1,32)),.,2.) }
        else { var %dibujo = $dibujo($gettok(%carta,1,32)) }

        drawpic -cs %ventana %x %y %w %h ciudadelas/ $+ %dibujo
        rline %ventana_control %c $puttok(%carta,0,4,32) 

      } 

      if ( %ornamentada ) { drawrect -r %ventana 15324629 2 %x %y %w %h }

      if ( %seleccionada ) { drawrect -r %ventana 11595006 2 %x %y %w %h }

    }

  }


} 

;dibuja_carta_mano id
;dibuja una carta en la @mano del jugador

alias dibuja_carta_mano {

  var %c = 0 , %total = $numtok($1-,32)

  while (%c < %total) {

    inc %c

    var %id = $gettok($1-,%c,32) 

    ;miramos primera fila, si hay menos de 5 cartas dibujamos ahí, si no pasamos a siguiente y repetimos
    var %l = 1
    while (%l) {

      var %nc = $columnas(%l,@cartasmano)
      if (%nc < 5) {
        dibuja %l %id mano | unset %l
      }
      else { inc %l }

    }

  }

}

;dibuja_carta_hechicero id
;dibuja una carta en @hechicero

alias dibuja_carta_hechicero {

  var %c = 0 , %total = $numtok($1-,32)

  while (%c < %total) {

    inc %c

    var %id = $gettok($1-,%c,32) 

    ;miramos primera fila, si hay menos de 5 cartas dibujamos ahí, si no pasamos a siguiente y repetimos
    var %l = 1
    while (%l) {

      var %nc = $columnas(%l,@cartashechicero)
      if (%nc < 5) {
        dibuja %l %id hechicero | unset %l
      }
      else { inc %l }

    }

  }

}

;dibuja fila id <>
;si añadimos 3ª parámetro, se dibuja y actualiza sobre @mano y no sobre @mesa

alias dibuja {

  if ($3) {

    if ($3 == mano) { var %ventana = $ventana(mano), %ventana_control = @cartasmano }
    if ($3 == hechicero) { var %ventana = $ventana(hechicero) , %ventana_control = @cartashechicero }
    if ($3 == mazo) { var %ventana = $ventana(mazo) , %ventana_control = @cartas_mazo }

  }
  else { var %ventana = $ventana(mesa), %ventana_control = @cartas }

  ;averiguamos el número de cartas en la fila
  var %columnas = $columnas($1,%ventana_control)

  var %columna = $calc(%columnas + 1)

  if ( ($3) && ($3 != mazo) ) { var %dibujo = $replace( $dibujo($2) ,.,2.) }
  else { var %dibujo = $dibujo($2) }

  drawpic -c %ventana $coordenadas(%columna,$1,$3) ciudadelas/ $+ %dibujo
  aline %ventana_control $2 $1 %columna 0 0 0

}

;$columnas(fila,ventana) devuelve el número de columnas usadas
alias columnas {

  ;obtenemos un listado "preliminar" para reducir el número de líneas entre las que buscar
  var %maxcolumnas = $fline( $2 , * $+ $chr(32) $+ $1 $+ $chr(32) $+ * , 0 ) , %c = 0 , %columnas = 0

  while ( %c < %maxcolumnas ) {

    inc %c

    var %l = $line($2, $fline( $2 , * $+ $chr(32) $+ $1 $+ $chr(32) $+ * , %c ))
    if ($gettok(%l,2,32) == $1) { inc %columnas }

  }

  return %columnas

}

;borra id <>
;borra la carta dada y mueve el resto para no dejar huecos en medio
;si pasamos un segundo parámetro, entenderá que la operación se realiza en @mano

alias borra {

  if ($2) {

    var %ventana = $ventana(mano) , %ventana_control = @cartasmano 
    var %w = 130 , %h = 210 

  }
  else { var %ventana = $ventana(mesa) , %ventana_control = @cartas , %w = 65 , %h = 105 }

  ;obtenemos datos de la carta: id fila(=jugador) columna
  var %ncarta = $fline(%ventana_control, $1 $+ $chr(32) $+ * ,1) , %carta = $line( %ventana_control , %ncarta )
  var %fila = $gettok(%carta,2,32) , %columna = $gettok(%carta,3,32)

  ;averiguamos el número de cartas en la fila
  var %columnas = $columnas(%fila,%ventana_control)

  ;borramos la columna final
  drawrect -rf %ventana 32768 1 $coordenadas(%columnas,%fila,$2) %w %h

  ;eliminamos los datos de la carta en cuestión de @ventana_control
  dline %ventana_control %ncarta
  dec %columnas

  ;dibujamos las cartas que quedan una columna por delante de donde estaban si estaban tras la borrada
  ;¡cuidado con el uso de comodines para la fila!, que ya me ha dado disgustos

  var %c = 1
  while ( %c <= %columnas ) {

    var %ncarta2 = $fline( %ventana_control , * $+ $chr(32) $+ %fila $+ $chr(32) $+ * , %c )
    var %carta2 = $line( %ventana_control , %ncarta2)
    var %fila2 = $gettok(%carta2,2,32) , %columna2 = $gettok(%carta2,3,32)

    if (%fila == %fila2) {

      if ( %columna2 > %columna ) { 

        ;no uso dibuja para que no me toque @ventana_control... 
        if ($2) { var %dibujo = $replace($dibujo( $gettok(%carta2,1,32)),.,2.)) }
        else { var %dibujo = $dibujo( $gettok(%carta2,1,32)) }

        drawpic -c %ventana $coordenadas( $calc( %columna2 - 1 ) , %fila , $2 ) ciudadelas/ $+ %dibujo )

        ;apuntamos la carta en nuestro array de "modificadas" para luego actualizar datos en @ventana_control
        var %modificadas = %modificadas $+ $chr(32) $+ %ncarta2

      }

    }
    else { 
      ;$columnas nos devuelve bien el valor, pero la búsqueda que hacemos nosotros para recorrer las columnas no es óptima
      inc %columnas 
    }

    inc %c

  }

  ;actualizamos datos de @ventana_control bajando el valor columna en uno a las cartas que estaban tras la borrada
  var %c = 1
  var %nmodificadas = $numtok(%modificadas,32)
  while (%c <= %nmodificadas) {

    var %ncarta2 = $gettok(%modificadas,%c,32)
    var %carta2 = $line( %ventana_control , %ncarta2)
    var %columna2 = $gettok(%carta2,3,32) , %resto = $gettok(%carta2,4-,32)
    rline %ventana_control %ncarta2 $gettok(%carta2,1,32) %fila $calc( %columna2 - 1 ) %resto

    inc %c

  }


}

;$coordenadas(columna,fila)
;si pasamos tercer parámetro, se calcularán las coordenadas para cartas grandes
;salvo que sea mazo, que maneja cartas pequeñas

alias coordenadas {

  if ( ($3) && ($3 != mazo) ) {

    var %x = $calc( ( ($1 - 2) * 130) + ( ($1 - 2) * 10 ) + 170 )
    var %y = $calc( ( ($2 - 1)  * 210 ) + ( ($2 - 1) * 6) + 25 )

  }
  else {

    var %x = $calc( ( ($1 - 1) * 65) + ( ($1 - 1) * 10 ) + 170 )
    var %y = $calc( ( ($2 - 1)  * 105 ) + ( ($2 - 1) * 6) + 25 )

  }

  return %x %y

}

;dibuja_jugador numero nombre puntos cartas oro corona(0/1) <desconectado>

alias dibuja_jugador {

  var %y = $calc( ( ($1 - 1)  * 105 ) + ( ($1 - 1) * 6) + 25 )
  var %x = 25

  if ($6) { drawrect -rdf $ventana(mesa) 11595006 1 %x %y 130 105 30 30 }
  else { drawrect -rdf $ventana(mesa) 9158285 1 %x %y 130 105 30 30 }

  if ($8) { drawrect -rdf $ventana(mesa) 9211074 1 %x %y 130 105 30 30 }

  drawrect -rd $ventana(mesa) 1 1 %x %y 130 105 30 30

  drawtext -o $ventana(mesa) 1 Arial 20 $calc(%x + 20) $calc(%y + 10) $2
  drawtext -o $ventana(mesa) 1 Arial 12 $calc(%x + 20) $calc(%y + 40) $texto(207) : $3
  drawtext -o $ventana(mesa) 1 Arial 12 $calc(%x + 20) $calc(%y + 52) $texto(208) : $4
  drawtext -o $ventana(mesa) 1 Arial 12 $calc(%x + 20) $calc(%y + 64) $texto(209) : $5

  if ($8) { drawtext -o $ventana(mesa) 1 Arial 12 $calc(%x + 20) $calc(%y + 84) $texto(203) }

}



;encuadra @ventana x y w h fonttype fontsize texto

;dibuja texto a partir de "x" e "y" encuadrado en un rectángulo de anchura "w".
;el parámetro "h" -altura- indica el salto en pixels a realizar entre líneas.

alias encuadra {

  window -c @encuadra
  window -hl @encuadra

  ;dividimos el texto en tokens y, a la vieja usanza, vamos juntando token a token y comparando
  ;con nuestro ancho en pixels. Cada vez que alcanzamos el ancho, cambiamos de línea. Guardamos
  ;el resultado en una ventana tipo "-hl" para acceder luego comodamente al mismo desde donde sea.

  var %total = $numtok($8-,32)
  var %c = 0
  var %linea = ""
  var %lineavieja = ""

  while (%c < %total) {

    inc %c

    var %lineavieja = %linea  
    var %linea = %linea $+ $chr(32) $+ $gettok($8-,%c,32)
    var %ancho = $width(%linea,$6,$7)

    if ( %ancho >= $4 ) { aline @encuadra %lineavieja | dec %c | unset %linea* | continue } 
    if ( %c == %total ) { aline @encuadra %linea | unset %linea* }

  }

  ;llegados a este punto, tenemos @encuadra con las líneas construidas,
  ;sólo queda copiar y pegar en nuestro rectángulo...

  %total = $line(@encuadra,0)
  %c = 0

  while ( %c < %total ) {

    inc %c

    drawtext $1 1 $6 $7 $2 $calc( $3 + ( $5 * %c ) ) $line(@encuadra,%c)

  }

}

;$sel_carta(x, y)
;devuelve el id de la carta seleccionada.

alias sel_carta {

  if ($3) {

    if ($3 == mano) { var %ventana = $ventana(mano) , %ventana_control = @cartasmano }
    if ($3 == hechicero) { var %ventana = $ventana(hechicero) , %ventana_control = @cartashechicero }
    var %w = 130 , %h = 210 
    if ($3 == mazo) {
      var %ventana = $ventana(mazo) , %ventana_control = @cartas_mazo 
      var %w = 65 , %h = 105
    }
  }
  else { var %ventana = $ventana(mesa) , %ventana_control = @cartas , %w = 65 , %h = 105 }

  ;cartas de distrito
  var %cartas = $line(%ventana_control,0), %c = 0

  while (%c < %cartas) {

    inc %c

    var %carta = $line(%ventana_control,%c)
    var %coordenadas = $coordenadas( $gettok(%carta,3,32) , $gettok(%carta,2,32), $3 )
    var %x = $gettok(%coordenadas,1,32)
    var %y = $gettok(%coordenadas,2,32)

    if $inrect($1,$2,%x,%y,%w,%h) { return $gettok(%carta,1,32) }

  }

  ;si estamos en @mano no miramos estas cosas...
  if (!$3) {

    ;jugadores
    var %jugadores = $line(@jugadores,0) , %c = 0
    var %x = 25

    while (%c < %jugadores) {

      inc %c

      var %jugador = $line(@jugadores,%c), %desconectado = $gettok(%jugador,7,32), %nombre = $gettok(%jugador,1,32)
      var %y = $calc( ( (%c - 1)  * 105 ) + ( (%c - 1) * 6) + 25 )

      if ( $inrect($1,$2,%x,%y,130,105) ) {
        if ((!%desconectado) && (%nombre != %cciudadelas.f.nombre)) { return $gettok(%jugador,1,32) }
      }

    }

  }

  ;boton_ok en @mano
  if ( ($3) && (%cciudadelas.v.cambiar_cartas) ) {
    if ( $inrect($1,$2,820,390,130,40) ) { return CH }
  }

  ;boton pagar al emperador en @mano
  if ( ($3) && (%cciudadelas.v.pagar) ) {
    if ( $inrect($1,$2,820,390,130,40) ) { return EMG }
  }

}
;TABLERO EOF

;SOCKETS

;conecta servidor <puerto>
alias conecta {

  ;limpiamos variables que pueden haber quedado de partidas anteriores
  carga_datos

  sockclose cciudadelas
  sockopen cciudadelas $1 $2

}

on 1:sockopen:cciudadelas:{

  dialog -x conectando
  if ($sockerr) { dibuja_error_conexion }
  else {

    dibuja_chat
    msg $texto(25)
    sockwrite -n cciudadelas N %cciudadelas.f.nombre

  }

}

alias dibuja_error_conexion { dialog -m error_conexion error_conexion }

alias dibuja_conectando { dialog -m conectando conectando }

dialog conectando {

  title $texto(8)
  size -1 -1 136 72
  option dbu
  text $texto(11), 1, 8 16 113 32, center
  button "Button", 2, 48 56 37 12, hide disable ok

}

dialog desconectado {

  title $texto(8)
  size -1 -1 136 72
  option dbu
  text $texto(26), 1, 8 8 113 32, center
  button "Ok", 2, 48 48 37 12,ok

}

dialog error_conexion {

  title $texto(8)
  size -1 -1 136 72
  option dbu
  text $texto(24), 1, 8 8 113 32, center
  button "Ok", 2, 48 48 37 12,ok

}


on 1:dialog:error_conexion:sclick:2:{ dibuja_inicio }

on 1:dialog:desconectado:sclick:2:{ dibuja_inicio }

on 1:sockclose:cciudadelas: {

  window -c $ventana(personajes)
  window -c $ventana(mesa)
  window -c $ventana(mano)
  window -c @chat
  window -c @edit
  dialog -m desconectado desconectado

}

on 1:sockread:cciudadelas:{

  var %d = 0
  sockread -n %d
  if (%d) { cciudadelas.procesa %d }

}

;SOCKETS EOF


;el primer parámetro nos indica qué tipo de elección hacemos (escoger para jugar, para matar o para robar...)
;los demás parámetros indican las cartas que debemos dibujar

alias dibuja_personajes {

  ;guardo en una variable el primer parámetro para saber qué tipo de elección hago
  ;cuando pulse sobre la carta y poder así contestar adecuadamente

  //echo dentro de dibuja_personajes: $1-
  %cciudadelas.v.dibuja_personajes = $1
  var %parm = $2-

  ;si estamos eligiendo a quien matar o robar, presentamos Personajes sin los descartados bocarriba y sin el asesino
  ;tampoco dibujamos a la bruja, si estamos jugando con ella
  if (%cciudadelas.v.dibuja_personajes == 2) || (%cciudadelas.v.dibuja_personajes == 3) || (%cciudadelas.v.dibuja_personajes == 4) {

    var %c = 0 , %total = $numtok(%cciudadelas.v.du,32)

    %parm = %cciudadelas.f.personajes

    if ( $istok(%parm,1,32) ) { %parm = $remtok(%parm,1,1,32) }
    if ( $istok(%parm,10,32) ) { %parm = $remtok(%parm,10,1,32) }

    while (%c < %total) {
      inc %c
      %parm = $remtok(%parm, $gettok(%cciudadelas.v.du,%c,32) ,1,32)
    }

  }

  ;si estamos eligiendo a quien robar, quitamos, además de los anteriores, al asesinado y al ladrón
  ;si hay bruja en juego, quitamos al embrujado
  if (%cciudadelas.v.dibuja_personajes == 3) {

    if (%cciudadelas.v.asesinado) { %parm = $remtok(%parm, %cciudadelas.v.asesinado ,1,32) }
    if (%cciudadelas.v.embrujado) { %parm = $remtok(%parm, %cciudadelas.v.embrujado ,1,32) }

    %parm = $remtok(%parm,2,1,32)

  }

  window -c $ventana(personajes)
  window -pbk[0] +d $ventana(personajes) 1 1 %cciudadelas.f.w %cciudadelas.f.w 

  drawfill -r $ventana(personajes) 32768 1 1 1

  carga_personajes @cartaspersonajes %cciudadelas.f.personajes

  drawrect -rdf $ventana(personajes) 11595006 1 590 30 240 210 30 30

  var %y = 30
  var %c = 0, %l = 0 , %p = 0

  var %total = $numtok(%cciudadelas.f.personajes,32)
  while (%c < %total) {

    inc %c
    inc %l
    inc %p

    var %linea = $line(@cartaspersonajes,%c)

    ;salto de línea a las 4 cartas
    if (%l == 5 ) { inc %y 220 | %p = 1 }

    var %x = $calc( ( (%p - 2) * 130) + ( (%p - 2) * 10 ) + 170 )

    if ( $istok( %parm , $gettok(%linea,1,32) ,32 ) ) {

      drawpic -c $ventana(personajes) %x %y ciudadelas/ $+ $gettok(%linea,6,32) 
      rline @cartaspersonajes %c $puttok( $puttok(%linea,%x,4,32) ,%y,5,32)

    }
    else {

      if (%l == 5) { dec %y 220 } 
      dec %p 
      dec %l

    }

  }

  ;si corresponde, dibujamos cuadro de descartados bocaarriba
  cuadro_descartados

}

;MENU PERSONAJES (ELEGIR, ASESINAR, ROBAR, EMBRUJAR...)
menu @* {

  mouse: { if ($ventana(personajes) == $active) { dentrocarta_personajes $mouse.x $mouse.y } }

  sclick: { 

    //echo activa: $active personajes: $ventana(personajes)

    if ($ventana(personajes) == $active) {

      var %id = $sel_carta_personajes($mouse.x, $mouse.y) 
      //echo id %id
      //echo dibuja_personajes %cciudadelas.v.dibuja_personajes
      if ( %id ) {

        ;elección para jugar
        if ( %cciudadelas.v.dibuja_personajes < 2 ) {

          sockwrite -n cciudadelas P %id
          unset %cciudadelas.v.dibuja_personajes
          window -c $ventana(personajes)

        }

        ;ASESINAR
        if ( %cciudadelas.v.dibuja_personajes == 2 ) {

          sockwrite -n cciudadelas K %id
          unset %cciudadelas.v.dibuja_personajes
          window -c $ventana(personajes)
          edita_boton K D2

        }

        ;ROBAR
        if ( %cciudadelas.v.dibuja_personajes == 3 ) {

          sockwrite -n cciudadelas R %id
          unset %cciudadelas.v.dibuja_personajes
          window -c $ventana(personajes)
          edita_boton R D2

        }

        ;EMBRUJAR
        if ( %cciudadelas.v.dibuja_personajes == 4 ) {

          sockwrite -n cciudadelas BR %id
          unset %cciudadelas.v.dibuja_personajes
          window -c $ventana(personajes)
          edita_boton BR D2

        }

        ;DESCARTAR (partida entre 2 jugadores)
        if ( %cciudadelas.v.dibuja_personajes == 5 ) {

          sockwrite -n cciudadelas DD %id
          unset %cciudadelas.v.dibuja_personajes
          window -c $ventana(personajes)

        }

      } 
    }
  }

}

alias dentrocarta_personajes {

  var %c = 0, %total = $line(@cartaspersonajes,0)

  while (%c < %total) {

    inc %c

    var %linea = $line(@cartaspersonajes,%c)
    var %x = $gettok(%linea,4,32)
    var %y = $gettok(%linea,5,32)
    var %marca = $gettok(%linea,7,32)

    if (%x != 0) {

      if ( $inrect($1,$2,%x,%y,130,210) ) {

        if (%marca) { continue }
        else {

          drawrect -r $ventana(personajes) 33023 3 %x %y 130 210 
          drawrect -rdf $ventana(personajes) 11595006 1 590 30 220 210 30 30
          rline @cartaspersonajes %c $puttok(%linea,1,7,32)
          drawtext -o $ventana(personajes) 1 Arial 15 670 45 $gettok(%linea,2,32)
          encuadra $ventana(personajes) 600 60 210 12 arial 11 $gettok(%linea,8-,32)

        }

      }
      else {

        drawrect -r $ventana(personajes) 1 3 %x %y 130 210 
        if (%marca) { rline @cartaspersonajes %c $puttok(%linea,0,7,32) }

      }

    }
  }

}

alias sel_carta_personajes {

  var %personajes = $line(@cartaspersonajes,0), %c = 0

  while (%c < %personajes) {

    inc %c

    var %personaje = $line(@cartaspersonajes,%c)
    var %x = $gettok(%personaje,4,32)
    var %y = $gettok(%personaje,5,32)

    if (%x != 0) {
      if ( $inrect($1,$2,%x,%y,130,210) ) { return $gettok(%personaje,1,32) }
    }

  }
}

alias dibuja_mano {

  window -c $ventana(mano)
  window -pbk[0] +d $ventana(mano) 1 1 %cciudadelas.f.w %cciudadelas.f.w 
  drawfill -r $ventana(mano) 32768 1 1 1

  window -c @cartasmano
  window -hl @cartasmano

}

;MENU HECHICERO y FARO(mazo)
;es prácticamente lo mismo que @mano, pero me monto demasiado chocho si no separo parte del código
menu @* {

  mouse: { 
    if ($ventana(hechicero) == $active) { dentrocarta $mouse.x $mouse.y hechicero } 
    if ($ventana(mazo) == $active) { dentrocarta $mouse.x $mouse.y mazo }
  }

  sclick: {
    if ($ventana(hechicero) == $active) {

      var %id = $sel_carta($mouse.x, $mouse.y, hechicero)
      window -c $ventana(hechicero)
      window -c @cartashechicero
      sockwrite -n cciudadelas WC %id
      dibuja_carta_mano %id

    }

    if ($ventana(mazo) == $active) { 

      var %id = $sel_carta($mouse.x, $mouse.y, mazo)
      window -c $ventana(mazo)
      window -c @cartas_mazo
      ;sockwrite -n cciudadelas WC %id
      sockwrite -n cciudadelas LH %id
      dibuja_carta_mano %id
      unset %cciudadelas.v.listaIDS
      edita_boton ET D1

    }
  }
}

;MENU MANO
menu @* {

  mouse: { if ($ventana(mano) == $active) { dentrocarta $mouse.x $mouse.y mano } }

  sclick: {
    if ($ventana(mano) == $active) {
      var %id = $sel_carta($mouse.x, $mouse.y, mano)
      if ( %id ) {

        ;USAR MUSEO
        if (%cciudadelas.v.museo) {

          sockwrite -n cciudadelas MU %id
          borra %id mano
          borra_cuadro
          edita_boton MU D2
          window -a $ventana(mesa)
          return

        }

        ;PAGAR AL EMPERADOR (moneda o carta)
        if (%cciudadelas.v.darcarta) {

          ;pagar ORO
          if (%id == EMG) { sockwrite -n cciudadelas EMG }

          ;pagar una CARTA
          else {
            sockwrite -n cciudadelas EMC %id 
            borra %id mano
          }

          borra_cuadro
          borra_boton_ok
          unset %cciudadelas.v.pagar
          unset %cciudadelas.v.darcarta
          window -a $ventana(mesa)

        }
        else {

          ;USAR LABORATORIO
          if (%cciudadelas.v.laboratorio == 1) {

            sockwrite -n cciudadelas L %id
            borra %id mano
            borra_cuadro
            edita_boton L D2
            window -a $ventana(mesa)

          }
          else {

            ;DESCARTAR
            if (%cciudadelas.v.descartar) {

              ;si está en la lista y no está seleccionada, la marcamos como tal
              if ($istok(%cciudadelas.v.descartar,%id,32)) {

                var %n = $fline(@cartasmano,%id $+ $chr(32) $+ *,1) , %carta = $line(@cartasmano,%n)

                if ($gettok(%carta,5,32) != D) {

                  rline @cartasmano %n $puttok(%carta,D,5,32) 

                  ;-si ya hemos seleccionado todas menos una de las cartas que tenemos que descartar, procedemos con el descarte
                  ;-si tenemos construida la Biblioteca y aún así estamos descartando, entonces es porque también tenemos el Observatorio,
                  ;lo que quiere decir que hemos robado 3 cartas pero que sólo tenemos que descartar una de ellas

                  var %des = $calc( $numtok(%cciudadelas.v.descartar,32) - 1) , %c = 0

                  if ( $maravilla_construida(62) ) { dec %des }

                  if ( $fline(@cartasmano,*D*,0) == %des ) {

                    ;en vista de los abundantes despistes, vamos a pedir una confirmación antes...
                    if ( $input($texto(163),yvw,$texto(45)) == $no ) {  rline @cartasmano %n $puttok(%carta,0,5,32)  }

                    else {

                      while (%c < %des) {
                        inc %c
                        var %n = $fline(@cartasmano, *D*,%c) , %id = $gettok($line(@cartasmano,%n),1,32)
                        var %dc = $addtok(%dc,%id,32)
                      }

                      ;una vez construida la lista, las borramos
                      var %c = 0,  %total = $numtok(%dc,32)
                      while (%c < %total) {
                        inc %c
                        var %id = $gettok(%dc,%c,32)
                        borra %id mano
                      }

                      sockwrite -n cciudadelas DC %dc
                      unset %cciudadelas.v.descartar
                      borra_cuadro
                      edita_boton ET D1
                      window -a $ventana(mesa)

                    }
                  }
                }
                ;si ya estaba seleccionada, la deseleccionamos
                else { rline @cartasmano %n $puttok(%carta,0,5,32)  }
              }
            }

            else {

              ;CAMBIAR CARTAS CON MAGO
              if (%cciudadelas.v.cambiar_cartas) {

                if (%id == CH) { 

                  ;obtengo lista de cartas a cambiar y envio orden
                  var %c = 0 , %total = $fline(@cartasmano,*CH*,0)

                  while (%c < %total) {

                    inc %c
                    var %n = $fline(@cartasmano,*CH*, %c ) , %id = $gettok( $line(@cartasmano,%n) ,1,32)
                    var %cambiadas = $addtok(%cambiadas,%id,32)
                    ;no borro en este bucle porque "borra" funciona con líneas y altero el número de las mismas cada vez que lo uso

                  }

                  var %c = 0
                  while ( %c < $numtok(%cambiadas,32) ) {

                    inc %c
                    borra $gettok(%cambiadas,%c,32) mano

                  }

                  borra_cuadro
                  borra_boton_ok

                  sockwrite -n cciudadelas C M %cambiadas
                  unset %cambiadas
                  unset %cciudadelas.v.cambiar_cartas
                  edita_boton C D2

                }
                else {

                  ;cambiar algunas cartas de la mano por cartas del MAZO (habilidad del mago)

                  var %n = $fline(@cartasmano,%id $+ $chr(32) $+ *,1) , %carta = $line(@cartasmano,%n)

                  if ($gettok(%carta,5,32) != CH) { rline @cartasmano %n $puttok(%carta,CH,5,32) }
                  ;si ya estaba seleccionada, la deseleccionamos
                  else { rline @cartasmano %n $puttok(%carta,0,5,32)  }

                }

              }

              else {
                ;CONSTRUIR

                ;comprobamos que es nuestro turno
                if ($gettok(%cciudadelas.v.turno,3,32)) {

                  ;si estamos muertos y jugamos gracias al Hospital, no podemos construir
                  if ( $gettok(%cciudadelas.v.turno,3,32) == 3 ) { msg $texto(248) | return }

                  ;si somos Navegante o la bruja con su habilidad, no podemos construir
                  if ( ( $gettok(%cciudadelas.v.turno,1,32) == 16 ) || ( ($gettok(%cciudadelas.v.turno,3,32) == 2) && (%cciudadelas.v.embrujado == 16) ) ) { msg $texto(164) }
                  else {

                    ;si estamos embrujados, no podemos construir :(
                    if ( (%cciudadelas.v.embrujado == $gettok(%cciudadelas.v.turno,1,32)) && ( $gettok(%cciudadelas.v.turno,3,32) != 2 ) ) { msg $texto(198) }
                    else {

                      ;si somos la Bruja en nuestro "primer turno", no podemos construir
                      if ( ($gettok(%cciudadelas.v.turno,1,32) == 10) && ($gettok(%cciudadelas.v.turno,3,32) == 1) ) { msg $texto(197) }
                      else {

                        ;si no hemos construido o bien si somos arquitecto y hemos construido menos de 3 distritos o bien somos el hechicero y hemos construido menos de 2 distritos, comprobamos precio
                        if ( (!%cciudadelas.v.construido) || ( ( $gettok(%cciudadelas.v.turno,1,32) == 7 ) && (%cciudadelas.v.construido < 3) ) || ( ( $gettok(%cciudadelas.v.turno,1,32) == 12 ) && (%cciudadelas.v.construido < 2) ) ) {

                          var %carta = $line(@distritos, $fline(@distritos, %id $+ $chr(32) $+ *,1) )
                          var %precio = $gettok( %carta ,3,32 )

                          ;reducimos el precio en 1 si es una maravilla y tenemos construida la manufactura (id 77)
                          if ( ( !$gettok(%carta,5,32) ) && ( $maravilla_construida(77) ) ) { dec %precio }

                          var %nombrecarta = $gettok(%carta,2,32)
                          var %oro = $gettok( $line(@jugadores, $fline(@jugadores, %cciudadelas.f.nombre $+ $chr(32) $+ *,1) ) ,4,32 )

                          if ( %precio > %oro ) { msg $texto(27) }
                          else { 

                            ;comprobamos que no tenemos una carta similar construida ya o bien que tenemos la cantera construida o bien somos el hechicero
                            if ( ( !$maravilla_construida(61) ) && ($distrito_construido(%nombrecarta)) && ($gettok(%cciudadelas.v.turno,1,32) != 12) ) {

                              msg $texto(28)

                            }
                            else {
                              ;comprobamos que no tenemos ya 8 distritos construidos
                              if ($construidos(%cciudadelas.f.nombre) == $calc(8 - %cciudadelas.g.tb)) { msg $texto(29, $calc(8 - %cciudadelas.g.tb) ) }
                              else {

                                inc %cciudadelas.v.construido
                                sockwrite -n cciudadelas B %id $gettok(%cciudadelas.v.turno,1,32)
                                borra %id mano

                                ;si es el campanario, dibujamos botón (es el único botón postconstrucción que dibujamos aquí, el resto van al leer "J"
                                if (%id == 79) { dibuja_boton TB $texto(229) }

                                window -a $ventana(mesa)

                              }
                            }
                          }
                        }
                        else { msg $texto(30) }
                      }
                    }
                  }

                }
                else { msg $texto(31) }
              } 
            }
          }
        }
      }


    }
  }

}

;$maravilla_construida(id) -> devuelve 1 si tenemos la maravilla construida
;si se pasa el nombre de un jugador como segundo parámetro, nos devolverá 1
;si ese jugador tiene la maravilla que hemos pasado.
alias maravilla_construida {

  if ($2) { var %fila =  $fline(@jugadores,$2 $+ $chr(32) $+ *,1) }
  else { var %fila = $fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1) }

  var %c = 0 , %total = $line(@cartas,0)
  while (%c < %total) {

    inc %c 

    var %carta = $line(@cartas,%c) , %filacarta = $gettok(%carta,2,32) , %id = $gettok(%carta,1,32)

    if ( %filacarta == %fila ) {
      if (%id == $1) { return 1 }
    }

  }

  return 0

}

;$distrito_construido(nombre) -> $distrito_construido(tienda) devuelve 1 si ya tenemos una tienda construida
;si se pasa el nombre de un jugador como segundo parámetro, nos devolverá 1
;si ese jugador tiene el distrito que hemos pasado.
alias distrito_construido {

  if ($2) { var %fila =  $fline(@jugadores,$2 $+ $chr(32) $+ *,1) }
  else { var %fila = $fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1) }

  var %c = 0 , %total = $line(@cartas,0)
  while (%c < %total) {

    inc %c 

    var %carta = $line(@cartas,%c) , %filacarta = $gettok(%carta,2,32) , %id = $gettok(%carta,1,32)

    var %nombrecarta = $gettok( $line(@distritos,$fline(@distritos, %id $+ $chr(32) $+ * ,1)) ,2,32)
    if ( %filacarta == %fila ) {
      if (%nombrecarta == $1) { return 1 }
    }

  }

  return 0

}

;$construidos(jugador) -> devuelve número de distritos construidos del jugador
alias construidos {

  var %fila = $fline(@jugadores,$1 $+ $chr(32) $+ *,1)
  var %c = 0 , %total = $line(@cartas,0), %construidos = 0
  while (%c < %total) {

    inc %c 

    var %carta = $line(@cartas,%c) , %filacarta = $gettok(%carta,2,32)
    if ( %filacarta == %fila ) { inc %construidos }

  }

  return %construidos

}

alias dibuja_chat {

  window -c @chat
  window -ebl15k[0] +d @Chat 1 1 %cciudadelas.f.w %cciudadelas.f.w 

}

on 1:input:@chat: {

  msgM < $+ %cciudadelas.f.nombre $+ > $1-
  sockwrite -n cciudadelas M $1-

}

on 1:input:@edit: {

  msgM < $+ %cciudadelas.f.nombre $+ > $1-
  sockwrite -n cciudadelas M $1-

}

on 1:close:@chat: {

  sockclose cciudadelas
  carga_datos
  window -c $ventana(mano)
  window -c $ventana(mesa)
  window -c $ventana(personajes)
  window -c @edit

}

;dibuja_botones <numeropersonaje> dibuja botones en función del personaje

;un segundo parámetro indica que se juega bien bruja bien usando el hospital
;BR -> bruja, no dibujamos botones de coger dinero y cartas
;D  -> muerto con hospital, sólo dibujamos botones de coger dinero y cartas

alias dibuja_botones {
  //echo dibuja_botones primer $1-
  if ( (!$2) || ($2 == D) ) {

    ;botones comunes a todos los personajes
    dibuja_boton GG $texto(32)
    dibuja_boton GC $texto(33)

  }

  if ( ( ( %cciudadelas.v.embrujado == $1 ) && (!$2) ) || ($2 == D) ) {
    ;no le dibujamos botones de habilidades especiales 
    //echo dibuja_botones embrujado
  }
  else {
    //echo dibuja_botones segundo $1-
    if ($1 == 1) { dibuja_boton K $texto(34) }
    if ($1 == 2) { dibuja_boton R $texto(35) }
    if ($1 == 3) { dibuja_boton C $texto(36) }
    if ($1 == 7) { dibuja_boton GEC $texto(37) }
    if ($1 == 8) { dibuja_boton KD $texto(38) }

    if ($1 == 10) { dibuja_boton BR $texto(194) }

    if ($1 == 16) {
      dibuja_boton NG $texto(166)
      dibuja_boton NC $texto(165) 
    }

    if ($1 == 12) { dibuja_boton W $texto(144) }

    if ($1 == 17) { dibuja_boton DP $texto(172) }

    if ($1 == 13) { dibuja_boton EM $texto(179) }

    if ($1 == 18) { dibuja_boton AR $texto(189) }

    if ( ($1 == 4) || ($1 == 5) || ($1 == 6) || ($1 == 8) || ($1 == 13) || ($1 == 14) || ($1 == 17) ) {

      dibuja_boton GD $texto(39)
      ;miramos a ver si tiene distritos cobrables, dibujamos el boton activado o desactivado en consecuencia

      if ( !$tiene_distritos($1) ) { edita_boton GD D2 }

    }

  }

  ;botones de maravillas

  ;fábrica
  if ( $maravilla_construida(67) ) {
    dibuja_boton F $texto(40) 
    ;si no tiene 2 monedas de oro, desactivamos botón
    if ( $gettok( $line(@sjugadores,$fline(@sjugadores, %cciudadelas.f.nombre $+ $chr(32) $+ *,1)) ,4,32) < 2 ) { edita_boton F D2 }
  }

  ;laboratorio
  if ( $maravilla_construida(69) ) {
    dibuja_boton L $texto(22) 
    ;si no tiene cartas en la mano, desactivamos el botón
    if (!$line(@cartasmano,0)) { edita_boton L D2 }
  }

  ;powderhouse
  if ( $maravilla_construida(76) ) {
    dibuja_boton PD $texto(226)
  }

  ;museo
  if ($maravilla_construida(78)) {
    dibuja_boton MU $texto(228)
  }

  //echo dibuja_botones final
  dibuja_boton ET $texto(41)

}

;tiene_distritos <numeropersonaje> devuelve 1 si hay algún distrito construido de ese "color", cero en caso contrario
alias tiene_distritos {

  var %personaje = $1
  if ($1 == 13) { var %personaje = 4 }
  if ($1 == 14) { var %personaje = 5 }
  if ($1 == 17) { var %personaje = 8 }

  var %fila = $fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1)
  var %c = 0 , %total = $line(@cartas,0)

  while (%c < %total) {

    inc %c

    var %d = $line(@cartas,%c), %id = $gettok(%d,1,32) , %cfila = $gettok(%d,2,32)

    if (%cfila == %fila) {
      var %color = $gettok($line(@distritos, $fline(@distritos,%id $+ $chr(32) $+ *,1) ) ,5,32)
      if (%color == %personaje) { return 1 }
    }

  }

  ;si tiene "la Escuela de Magia", ya tiene un distrito de color por narices
  ;¡lo que no significa que tenga un personaje que cobre por color!
  if ( $maravilla_construida(64) ) {
    if ( ($1 == 4) || ($1 == 5) || ($1 == 6) || ($1 = 8) || ($1 == 13) || ($1 == 14) || ($1 == 17) ) { return 1 }
  }

  return 0

}

alias borra_botones {

  var %c = 0 , %total = $line(@botones,0) , %y = 590 , %x = 25
  while (%c < %total) {

    inc %c

    drawrect -rf $ventana(mesa) 32768 3 %x %y 130 40
    %x = $calc( ( 130 * %c + 10 * %c) + 25 )

  }

  dline @botones 1-

}

;dibuja_boton id texto
alias dibuja_boton {

  var %y = 590
  var %x = 25

  ;averiguo cuántos botones hay para añadir el nuevo en el lugar apropiado
  var %total = $line(@botones,0)
  inc %x $calc( 130 * %total + 10 * %total)

  drawrect -rf $ventana(mesa) 15324629 1 %x %y 130 40 
  drawrect -r $ventana(mesa) 7209070 3 %x %y 130 40 
  drawtext -o $ventana(mesa) 1 Arial 14 $calc(%x + 20) $calc(%y + 10) $2-

  aline @botones $1 %x %y D1 0 $2-

}

;edita_boton id acción
;las acciones posibles son: "ilumina" , "apaga" , "A" , "D1" , "D2"  "borra"
alias edita_boton {

  var %n = $fline(@botones,$1 $+ *,1) , %boton = $line(@botones, %n )
  var %x = $gettok(%boton,2,32) , %y = $gettok(%boton,3,32) , %status = $gettok(%boton,4,32) ,%texto = $gettok(%boton,6-,32)

  var %colorborde = 7209070 , %colorfondo = 15324629


  if ( $2 == ilumina ) {
    if ( %status != D2 ) {

      %colorborde = 33023 
      %boton = $puttok(%boton,1,5,32)
      rline @botones %n %boton

    }
  }

  if ( $2 == apaga ) {

    %colorborde = 7209070 
    %boton = $puttok(%boton,0,5,32)
    rline @botones %n %boton

  }

  if ( ($2 == ilumina) || ($2 == apaga) ) { }
  else { %status = $2 }

  if ( %status == A ) { %colorfondo = 11595006 | rline @botones %n $puttok(%boton,A,4,32) }
  if ( %status == D1 ) { %colorfondo = 15324629 | rline @botones %n $puttok(%boton,D1,4,32) }
  if ( %status == D2 ) { %colorfondo = 9158285 | rline @botones %n $puttok(%boton,D2,4,32) }

  drawrect -rf $ventana(mesa) %colorfondo 3 %x %y 130 40
  drawrect -r $ventana(mesa) %colorborde 3 %x %y 130 40
  drawtext -o $ventana(mesa) 1 Arial 14 $calc(%x + 20) $calc(%y + 10) %texto

  if ( %status == borra ) { drawrect -rf $ventana(mesa) 32768 3 %x %y 130 40 | dline @botones %n }

}

alias dentro_boton {

  var %c = 0, %total = $line(@botones,0)

  while (%c < %total) {

    inc %c

    var %linea = $line(@botones,%c)
    var %id = $gettok(%linea,1,32)
    var %x = $gettok(%linea,2,32)
    var %y = $gettok(%linea,3,32)
    var %marca = $gettok(%linea,5,32) , %status = $gettok(%linea,4,32)

    if ( $inrect($1,$2,%x,%y,130,40) ) {
      if ((%marca == 0) && (%status != D2)) {
        edita_boton %id ilumina 
      }
    }
    else {
      if (%marca == 1) {
        edita_boton %id apaga
      }
    }

  }

}

alias sel_boton {

  var %botones = $line(@botones,0), %c = 0

  while (%c < %botones) {

    inc %c

    var %boton = $line(@botones,%c)
    var %x = $gettok(%boton,2,32)
    var %y = $gettok(%boton,3,32)
    var %id = $gettok(%boton,1,32)
    var %status = $gettok(%boton,4,32)

    if ( $inrect($1,$2,%x,%y,130,40) ) {
      if (%status != D2) { 
        edita_boton %id A
        return %id
      }
    }

  }

}

alias cciudadelas.procesa {

  echo -s SERVER: $1-

  if ( $1 == S ) {

    carga_datos
    dibuja_mesa 
    dibuja_mano
    msg $texto(42)
    %cciudadelas.f.personajes = $2-
    carga_personajes @cartaspersonajes %cciudadelas.f.personajes

  }

  if ( $1 == NJ ) {

    msg $texto(43) $2
    aline -lh @Chat $2    
    flash @chat

  }

  if ( $1 == N ) {

    aline @jugadores $2-
    dibuja_jugador $line(@jugadores,0) $2- 

  }

  if ( $1 == J ) {

    var %l = $fline(@jugadores,$2 $+ *,1)
    dibuja_jugador %l $2-
    rline @jugadores %l $2-

    ;si estamos en nuestro turno y nos envían una línea J sobre nosotros,
    ;tal vez hayamos ganado oro u obtenido cartas que nos permitan hacer cosas
    ;miramos a ver si hay que REACTIVAR ALGÚN BOTON (cobrar distritos, fábrica, laboratorio)
    ;con las maravillas, hay que comprobar que el botón existe antes de editarlo...

    if ($gettok(%cciudadelas.v.turno,3,32)) {

      ;Ornamentar
      if ( ( %cciudadelas.v.embrujado != $gettok(%cciudadelas.v.turno,1,32) ) || (( %cciudadelas.v.embrujado == $gettok(%cciudadelas.v.turno,1,32) ) && ($gettok(%cciudadelas.v.turno,3,32) == 2)) ) {
        if ($gettok(%cciudadelas.v.turno,1,32) == 18 ) {
          if ( (!%cciudadelas.v.artista) || (%cciudadelas.v.artista < 4) ) {
            ;si tiene dinero, activamos el boton
            if ( $gettok($line(@jugadores,$fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1)) ,4,32) > 1 ) {
              edita_boton AR D1
            }
          }
        }
      }

      ;Cobrar Distritos de color tras construir
      if ( ( %cciudadelas.v.embrujado != $gettok(%cciudadelas.v.turno,1,32) ) || (( %cciudadelas.v.embrujado == $gettok(%cciudadelas.v.turno,1,32) ) && ($gettok(%cciudadelas.v.turno,3,32) == 2)) ) {
        var %tiene = $tiene_distritos( $gettok( %cciudadelas.v.turno ,1,32) )
        if ( (%tiene) && (!%cciudadelas.v.gd) ) {
          edita_boton GD D1 
        }
      }

      ;usar Fábrica tras ganar dinero
      if ( $maravilla_construida(67) ) { 
        if ( ( $gettok($line(@jugadores,$fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1)) ,4,32) > 1 ) && (!%cciudadelas.v.fabrica) ) {
          if ($fline(@botones, F $+ $chr(32) $+ *,1)) { edita_boton F D1 }
          else { dibuja_boton F $texto(40) }
        }
        ;si teníamos el botón activo y hemos gastado el dinero, lo apagamos
        else {
          if ($fline(@botones, F $+ $chr(32) $+ *,1)) { edita_boton F D2 }
        }
      }

      ;usar Laboratorio para descartar una carta y ganar dinero, tras robar cartas
      if ( $maravilla_construida(69) ) {
        if ( ($line(@cartasmano,0) ) && (%cciudadelas.v.laboratorio != 2) ) {
          if ($fline(@botones, L $+ $chr(32) $+ *,1)) { edita_boton L D1 }
          else { dibuja_boton L $texto(22) } 
        }
      }

      ;si acabamos de construir el polvorín, dibujamos el botón
      if ( $maravilla_construida(76) ) {
        if (!$fline(@botones, PD $+ $chr(32) $+ *,1)) { dibuja_boton PD $texto(226) }
      }

      ;si acabamos de construir museo y tenemos cartas, dibujamos boton
      if ($maravilla_construida(78)) {
        if ( ($line(@cartasmano,0) ) && (%cciudadelas.v.museo != 2) ) {
          if ($fline(@botones, MU $+ $chr(32) $+ *,1)) { edita_boton MU D1 }
          else { dibuja_boton MU $texto(228) } 
        }
      }
    }

  }

  if ( $1 == GC ) { dibuja_carta_mano $2- | cuadro_descartados | window -a $ventana(mano) }

  if ( $1 == GD ) { msg $texto(44,$2-) }

  if ( $1 == DC ) {
    %cciudadelas.v.descartar = $2-
    drawrect -rdf $ventana(mano) 11595006 1 820 25 130 210 30 30
    drawtext $ventana(mano) 1 arial 18 837 30  $texto(45)
    encuadra $ventana(mano) 833 65 120 12 arial 12 $texto(46)

    ;desactivamos botón de acabar turno para que no se nos escaqueen
    edita_boton ET D2

  }

  if ( $1 == LH ) {

    ;nos envían listado de cartas disponibles en el mazo tras haber construido el faro
    edita_boton ET D2
    dibuja_mazo $2-

  }

  if ( $1 == GG ) { msg $2 $texto(47) }

  if ( $1 == GCM ) {

    if ($4) { %m = ( $4- ) }
    msg $texto(48,$2-)
    unset %m

  }

  if ( $1 == DCM ) { msg $texto(49,$2-) }

  if ( $1 == DU ) {

    msg $texto(50) $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$2 $+ $chr(32) $+ *,1)) ,2,32) 
    cuadro_descartados

  }

  if ( $1 == DD ) { msg $texto(51) }

  if ( $1 == M ) { msgM < $+ $2 $+ > $3-  }  

  if ( $1 == Q ) {

    msg $texto(52,$2-)

    var %njugador = $fline(@jugadores,$2 $+ $chr(32) $+ *,1) , %jugador = $line(@jugadores,%njugador)
    ;si ya estábamos jugando, le marcamos en rojo para saber uqe no está
    if (%cciudadelas.f.personajes) {

      rline @jugadores %njugador %jugador desconectado
      dibuja_jugador %njugador %jugador desconectado 

    }

    dline -l @chat $fline(@chat,* $+ $2,1,1) 

  }

  if ( $1 == P ) { 

    msg $texto(53,$2-)
    if ( $2 == %cciudadelas.f.nombre ) { 
      dibuja_personajes 1 $3- 
      cuadro_personajes $texto(160) $texto(216)
    }

  }

  if ( $1 == NT ) {

    unset %cciudadelas.v.*

    drawpic $ventana(mesa) 820 390 ciudadelas/ciudadelas_personaje.jpg
    msg $texto(54,$2-)

    cuadro_descartados

  }

  if ( $1 == B ) {

    ;B jugador idcartaconstruida
    var %l = $fline(@distritos,$3 $+ $chr(32) $+ *,1)
    var %j = $fline(@jugadores,$2 $+ $chr(32) $+ *,1)
    msg $texto(55,$2-) $replace( $gettok( $line(@distritos, %l) ,2,32 ),_, $chr(32) )
    dibuja %j $3

  }

  if ( $1 == K ) {

    var %personaje = $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$3 $+ $chr(32) $+ *,1) ) ,2,32)
    msg $texto(56,$2-) %personaje

  }

  if ( $1 == PD ) {

    ;PD quién_destruye nombre_víctima id_distrito_destruido
    ;destruyen distrito usando powderhouse
    %distrito = $replace($gettok( $line(@distritos, $fline(@distritos,$4 $+ $chr(32) $+ *,1)) ,2,32),_,$chr(32))
    msg $texto(251,$2-)
    unset %distrito
    borra 76
    borra $4

    ;si era el museo, borramos variable asociada
    if ($4 == 78) { unset %cciudadelas.g.bajo_museo }

  }

  if ( $1 == KD ) {

    %distrito = $replace($gettok( $line(@distritos, $fline(@distritos,$3 $+ $chr(32) $+ *,1)) ,2,32),_,$chr(32))
    msg $texto(57,$2-)
    borra $3

    ;si tenemos construido el cementerio, no somos el condotiero y tenemos 1 moneda de oro, dibujamos el botón del Cementerio
    if ( ($maravilla_construida(66)) && (!$gettok(%cciudadelas.v.turno,3,32)) ) {
      if ( $gettok($line(@jugadores,$fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1)) ,4,32) > 0 ) {

        dibuja_boton CY $texto(58)
        window -a $ventana(mesa)

      }
    }
    unset %distrito

    ;si era el museo, borramos variable asociada
    if ($3 == 78) { unset %cciudadelas.g.bajo_museo }

  }

  if ( $1 == CY ) {

    %carta = $gettok($line(@distritos,$fline(@distritos, $3 $+ $chr(32) $+ *,1)) ,2,32)
    msg $texto(59,$2-)
    ;si somos el que ha usado el cementerio, nos dibujamos la carta en la mano
    if ($2 == %cciudadelas.f.nombre) { dibuja_carta_mano $3 }
    unset %carta

  }

  if ( $1 == R ) {

    %personaje = $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$3 $+ $chr(32) $+ *,1) ) ,2,32)
    msg $texto(60,$2-)
    unset %personaje

  }

  if ( $1 == BR ) {

    %personaje = $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$3 $+ $chr(32) $+ *,1) ) ,2,32)
    msg $texto(195,$2-)
    unset %personaje

  }

  if ( $1 == CM ) { msg $texto(61,$2-) }

  if ( $1 == C ) {

    ;cambio de cartas del mago
    ;reseteamos @mano
    dibuja_mano

    var %c = 0 , %total = $numtok($2-,32)
    while (%c < %total) {
      inc %c
      dibuja_carta_mano $gettok($2-,%c,32)
    }

  }

  if ( $1 == ST ) {

    %personaje = $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$2 $+ $chr(32) $+ *,1) ) ,2,32)

    if ($2 == 5) { %cciudadelas.v.obispo = $3 }
    if ($2 == 10) { %cciudadelas.v.bruja = $3 }

    drawpic $ventana(mesa) 820 390 ciudadelas/ $+ $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$2 $+ $chr(32) $+ *,1) ) ,6,32)
    if ($4) { msg $texto(62) | %cciudadelas.v.turno = $2- | dibuja_botones $2 | window -a $ventana(mesa) }
    else { msg $texto(65,$2-) }
    unset %personaje 

  }

  ;semiturno de la Bruja usando las habilidades del embrujado :o
  ;la estructura es la misma que la de ST
  if ($1 == STB) {

    borra_botones

    %personaje = $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$2 $+ $chr(32) $+ *,1) ) ,2,32)
    if ($2 == 5) { %cciudadelas.v.obispo = $3 }
    drawpic $ventana(mesa) 820 390 ciudadelas/ $+ $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$2 $+ $chr(32) $+ *,1) ) ,6,32)
    msg $texto(196,$2-)
    if ($4) { %cciudadelas.v.turno = $2- | dibuja_botones $2 BR | window -a $ventana(mesa) }

    unset %personaje

  }

  ;semiturno de Muerto con Hospital
  ;la estructura es la misma que la de ST
  if ($1 == STD) {

    borra_botones

    %personaje = $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$2 $+ $chr(32) $+ *,1) ) ,2,32)
    drawpic $ventana(mesa) 820 390 ciudadelas/ $+ $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$2 $+ $chr(32) $+ *,1) ) ,6,32)
    msg $texto(247,$2-)
    if ($4) { %cciudadelas.v.turno = $2- | dibuja_botones $2 D | window -a $ventana(mesa) }

    unset %personaje

  }

  if ( $1 == ET ) {

    unset %cciudadelas.v.construido
    unset %cciudadelas.v.turno
    unset %cciudadelas.v.gd
    unset %cciudadelas.v.dibuja_personajes
    unset %cciudadelas.v.fabrica
    unset %cciudadelas.v.diplomatico
    unset %cciudadelas.v.destruir_distrito
    unset %cciudadelas.v.laboratorio
    unset %cciudadelas.v.cambiar_cartas
    unset %cciudadelas.v.museo

    borra_botones

    %personaje = $gettok( $line(@cartaspersonajes, $fline(@cartaspersonajes,$2 $+ $chr(32) $+ *,1) ) ,2,32)
    if ( ($3 == DD) || ($3 == DU) ) { msg $texto(66) }
    if ($3 == K) { msg $texto(67) }
    if ($3 == DC) { msg $texto(202) }
    if ($3 == BRF) { msg $texto(255) }

    unset %personaje

  }

  if ( $1 == L ) { msg $texto(68,$2-) }

  if ( $1 == MU ) {

    msg $texto(253,$2-) 
    inc %cciudadelas.g.bajo_museo

  }

  if ( $1 == EG ) {

    borra_botones
    msg $texto(69,$2-)

  }

  if ( $1 == E ) { msg $texto($2) }

  if ($1 == NG) { msg $texto(167,$2) }

  if ($1 == TX) { msg $texto(168,$2-) }

  if ($1 == WL) {

    ;dibujamos una ventana con las cartas de la víctima para que el hechicero elija
    ;habría estado bien hacer funciones genéricas para las ventanitas... :(

    window -c $ventana(hechicero)
    window -pbk[0] +d $ventana(hechicero) 1 1 %cciudadelas.f.w %cciudadelas.f.w 
    drawfill -r $ventana(hechicero) 32768 1 1 1

    window -c @cartashechicero
    window -hl @cartashechicero

    dibuja_carta_hechicero $3-

    drawrect -rdf $ventana(hechicero) 11595006 1 820 25 130 210 30 30
    drawtext $ventana(hechicero) 1 arial 18 826 35  $texto(144)
    encuadra $ventana(hechicero) 830 56 120 12 arial 12 $texto(169,$2)

  }

  if ($1 == WC) {

    msg $texto(170,$2-)
    if ($4) { borra $4 mano }

  }

  if ($1 == AB) { msg $texto(171,$2-) }

  if ($1 == DP) {

    ;recibimos diplomático$2 víctima$3 distritodiplomatico$4 distritovictima$5
    msg $texto(176,$2-)

    ;intercambiamos los distritos
    var %ncarta1 = $fline(@cartas,$4 $+ $chr(32) $+ *,1) , %carta1 = $line(@cartas,%ncarta1)
    var %ncarta2 = $fline(@cartas,$5 $+ $chr(32) $+ *,1) , %carta2 = $line(@cartas,%ncarta2)
    rline @cartas %ncarta1 $puttok(%carta1,$5,1,32)
    rline @cartas %ncarta2 $puttok(%carta2,$4,1,32)

    drawpic -c $ventana(mesa) $coordenadas( $gettok(%carta1,3,32) , $gettok(%carta1,2,32) ) ciudadelas/ $+ $dibujo($5)
    drawpic -c $ventana(mesa) $coordenadas( $gettok(%carta2,3,32) , $gettok(%carta2,2,32) ) ciudadelas/ $+ $dibujo($4)

  }

  if ($1 == QG) { msg $texto(188,$2-) }

  if ($1 == PH) { msg $texto(245,$2-) }

  if ($1 == HT) { msg $texto(246,$2-) }

  if ($1 == TB) { msg $texto(254,$2-) | %cciudadelas.g.tb = 1 }

  if ($1 == AR) {

    %distrito = $gettok($line(@distritos,$fline(@distritos,$3 $+ $chr(32) $+ *,1)) ,2,32)
    msg $texto(193,$2-) 
    unset %distrito

    ;tras avisar, lo marcamos como ornamentado
    var %ncarta = $fline(@cartas,$3 $+ $chr(32) $+ *,1) , %carta = $line(@cartas,%ncarta)
    var %carta = $puttok(%carta,1,6,32)
    rline @cartas %ncarta %carta

  }

  if ($1 == MDD) {

    ;estamos jugando 2 y en la elección de personaje se nos pide que descartemos uno
    dibuja_personajes 5 $2-
    cuadro_personajes $texto(45) $texto(215)

  }

  if ($1 == EMN) { 

    if ($3 == %cciudadelas.f.nombre) { edita_boton ET D1 }
    msg $texto(183,$2-)

  }

  if ($1 == EMG) {

    if ($3 == %cciudadelas.f.nombre) { edita_boton ET D1 }
    msg $texto(184,$2-)

  }

  if ($1 == EMC) {

    if ($3 == %cciudadelas.f.nombre) {
      if ($4) { dibuja_carta_mano $4 }
      edita_boton ET D1 
    }
    msg $texto(185,$2-)

  }

  if ($1 == EM) {

    msg $texto(180,$2-)
    ;si nos han dado la corona, tenemos que pagar bien con una moneda de oro o bien con una carta de nuestra mano
    if ($3 == %cciudadelas.f.nombre) {

      ;si no tenemos ni dinero ni cartas, no nos molestamos en dibujar nada
      var %linea = $line(@jugadores,$fline(@jugadores,%cciudadelas.f.nombre $+ $chr(32) $+ *,1))
      var %oro = $gettok(%linea,4,32) , %cartas = $gettok(%linea,3,32)

      if ( (!%oro) && (!%cartas) ) { ;el servidor se encargará de avisar }
      else { 

        ;cuadro explicativo
        drawrect -rdf $ventana(mano) 11595006 1 820 25 130 210 30 30
        drawtext $ventana(mano) 1 arial 18 826 35  $texto(146)
        encuadra $ventana(mano) 830 56 120 12 arial 12 $texto(181)

        ;boton para pagar moneda
        ;si no tiene dinero, no lo dibujamos
        if ( %oro ) { 

          drawrect -rf $ventana(mano) 15324629 1 820 390 130 40 
          drawrect -r $ventana(mano) 7209070 3 820 390 130 40 
          drawtext -o $ventana(mano) 1 Arial 14 870 400 $texto(182)

        }

        ;uso dos variables de control (pagar y darcarta) para evitar
        ;dibujar los márgenes del botón de pago y la iluminación 
        ;cuando no he dibujado el botón porque no hay dinero


        window -a $ventana(mano)
      }

    }

  }

}

;si hay personajes descartados bocaarriba, dibuja un cuadro en @mano y @peronajes
;listándolos
;en caso contrario dibujamos uno en verde (para borrar)
alias cuadro_descartados {

  if (%cciudadelas.v.du) {

    var %total = $numtok(%cciudadelas.v.du,32) , %y = 470

    if ( $window($ventana(mano),0) ) {

      drawrect -rdf $ventana(mano) 11595006 1 820 450 130 125 30 30
      drawrect -rd $ventana(mano) 1 1 820 450 130 125 30 30
      drawtext -o $ventana(mano) 1 Arial 16 830 460 $texto(201)

      var %x = 0
      while (%x < %total) {

        inc %x

        drawtext $ventana(mano) 1 Arial 16 830 $calc(%y + (20 * %x)) $gettok($line(@cartaspersonajes,$fline(@cartaspersonajes, $gettok( %cciudadelas.v.du , %x ,32) $+ $chr(32) $+ *,1)),2,32)

      }

    }

    if ( $window($ventana(personajes),0) ) {

      drawrect -rdf $ventana(personajes) 11595006 1 820 450 130 125 30 30
      drawrect -rd $ventana(personajes) 1 1 820 450 130 125 30 30
      drawtext -o $ventana(personajes) 1 Arial 16 830 460 $texto(201)

      var %x = 0
      while (%x < %total) {

        inc %x

        drawtext $ventana(personajes) 1 Arial 16 830 $calc(%y + (20 * %x)) $gettok($line(@cartaspersonajes,$fline(@cartaspersonajes, $gettok( %cciudadelas.v.du , %x ,32) $+ $chr(32) $+ *,1)),2,32)

      }

    }

  }
  else {

    if ( $window($ventana(mano),0) ) { drawrect -rdf $ventana(mano) 32768 1 820 450 130 125 30 30 }
    if ( $window($ventana(personajes),0) ) { drawrect -rdf $ventana(personajes) 32768 1 820 450 130 125 30 30 }

  }

}

;mensaje <texto> -> dibuja mensaje en las diversas ventanas
alias mensaje {

  if ( $window($ventana(mesa),0) ) {

    drawrect -rdf $ventana(mesa) 11595006 1 820 250 130 125 30 30
    drawrect -rd $ventana(mesa) 1 1 820 250 130 125 30 30
    drawrect $ventana(mesa) 1 1 835 348 100 20
    encuadra $ventana(mesa) 826 253 120 14 arial 14 $1-

  }

  if ( $window($ventana(mano),0) ) {

    drawrect -rdf $ventana(mano) 11595006 1 820 250 130 125 30 30
    drawrect -rd $ventana(mano) 1 1 820 250 130 125 30 30
    drawrect $ventana(mano) 1 1 835 348 100 20
    encuadra $ventana(mano) 826 253 120 14 arial 14 $1-

  }

  if ( $window($ventana(personajes),0) ) {

    drawrect -rdf $ventana(personajes) 11595006 1 820 250 130 125 30 30
    drawrect -rd $ventana(personajes) 1 1 820 250 130 125 30 30
    drawrect $ventana(personajes) 1 1 835 348 100 20
    encuadra $ventana(personajes) 826 253 120 14 arial 14 $1-

  }

}

;msgM texto -> dibuja en chat y en las ventanas el mensaje.
alias msgM {

  echo @chat $time $1-
  mensaje $1-

}

;lo mismo que msgM, sólo que colorea de marron lo que saca en Chat
alias msg {

  echo @chat $time 5 $1-
  mensaje $1-

}

alias texto {

  tokenize 32 $1-
  return $eval( $gettok($line(@mensajes, $fline(@mensajes, $1 $+ * ,1)),2-,32) , 2 )

}

;carga_personajes @ventana %listapersonajes -> genera la ventana oculta con los personajes activos para la partida
alias carga_personajes {

  window -c @temp
  window -c $1

  window -hl @temp
  window -hl $1

  loadbuf -e @temp ciudadelas/personajes.txt

  var %c = 0
  while (%c < 18) {
    inc %c
    var %lineapersonaje = $line(@temp,%c) , %personaje = $gettok(%lineapersonaje,1,32)
    if $istok($2-,%personaje,32) {
      aline $1 %lineapersonaje 
    } 
  }

  window -c @temp

}

;todo lo que sigue a continuación es muy cutre, pero funciona

;al iniciar dibujo una ventana, maximizo y mido dimensiones,
;esto me servirá para dibujar luego el resto de las ventanas
;"maximizadas" sin tener que maximizarlas (sic) y poder usar
;de este modo la cutrada de meter un edit en una picture window
alias mide_ventana {

  window -x @temp
  window -a @temp
  %cciudadelas.f.w = $window(@temp).w
  %cciudadelas.f.h = $window(@temp).h

  ;si tienen una resolución inferior a 1024x768 avisamos de que no va a funcionar
  if (%cciudadelas.f.w < 1000) { dialog -m resolucion resolucion }

  window -r @temp
  window -c @temp

}


;dialog avisando de resolución inferior a 1024x768
dialog resolucion {

  title $texto(3)
  size -1 -1 136 72
  option dbu
  text $texto(221), 1, 8 8 113 32, center
  button "Ok", 2, 48 48 37 12,ok

}

;cuando dan al ok de resolucion, cerramos mirc
on 1:dialog:resolucion:close:0:{
  exit
}

alias dibuja_edit {

  window -c @edit
  window -Beh +d @edit 837 350 98 18 arial 12 

}

;EN CUALQUIER VENTANA, DIBUJAMOS EDIT
menu @* {

  sclick {
    if ( $inrect( $mouse.mx , $mouse.my ,835 ,348,100,20)  ) {
      dibuja_edit
      window -a @edit
    }
  }
  rclick { dibuja_inicio }

}

dialog -l jugar {
  title mCitadels $cversion
  size -1 -1 136 120
  option dbu
  link $texto(256) , 8, 24 104 83 8
  tab $texto(3) , 9, 0 0 131 95
  edit "", 1, 40 24 58 10, tab 9 autohs
  edit "", 2, 40 40 58 10, tab 9
  edit "", 3, 40 56 58 10, tab 9 limit 8
  button $texto(8) , 7, 48 72 37 12, tab 9 flat ok
  text $texto(2) , 4, 8 24 25 8, tab 9 right
  text $texto(4) , 5, 8 40 25 8, tab 9 right
  text $texto(6) , 6, 8 56 25 8, tab 9 right
  tab $texto(9) , 10
  edit "", 11, 64 24 58 10, tab 10
  edit "", 12, 64 40 58 10, tab 10
  text $texto(4) , 14, 8 24 49 8, tab 10 right
  text $texto(5), 15, 8 40 49 8, tab 10 right
  button $texto(160), 13, 8 56 53 12, tab 10 flat
  button $texto(12), 16, 8 72 53 12, tab 10 flat
  button $texto(13), 17, 72 56 45 12, tab 10 flat
  button $texto(7), 22, 72 72 45 12, tab 10 flat
  tab $texto(210), 18
  ;opción para conectarse a un servidor de partidas, en desuso
  ;check $texto(211), 19, 8 24 106 10, tab 18 flat
  list 20, 8 48 50 26, tab 18 size
  text $texto(212), 21, 8 40 25 8, tab 18
  edit "", 23, 8 80 50 10, tab 18 autohs
  text $texto(220), 24, 65 80 49 8, tab 18
}


alias dibuja_inicio {

  dialog -m jugar jugar

  ;si no está cargado el servidor, anulamos menus del mismo
  if (!$script(sciudadelas.mrc)) { did -b jugar 11,12,14,15,13,16,17 }
  else {
    if (%sciudadelas.f.partida) { did -o jugar 12 1 %sciudadelas.f.partida }
    if (%sciudadelas.f.puerto) { did -o jugar 11 1 %sciudadelas.f.puerto }
    if ( ($sock(sciudadelasC*,0)) || ($sock(sciudadelasLISTEN)) ) {
      did -ob jugar 16 1 $sock(sciudadelasC*,0) $texto(14) 
      did -e jugar 22
    }
    else { did -b jugar 22 }

    if (%sciudadelas.v.pos) { 
      did -b jugar 13
    }
    did -b jugar 17

    if ( ($sock(sciudadelasC*,0)) && (!%sciudadelas.v.pos) ) { did -e jugar 17 }

  }

  ;rellenamos datos de cliente
  if (%cciudadelas.f.host) { did -o jugar 1 1 %cciudadelas.f.host }
  if (%cciudadelas.f.puerto) { did -o jugar 2 1 %cciudadelas.f.puerto }
  if (%cciudadelas.f.nombre) { did -o jugar 3 1 %cciudadelas.f.nombre }
  if (%sciudadelas.f.nat) { did -o jugar 23 1 %sciudadelas.f.nat }

  ;si hay una partida en marcha, desactivamos campos y activamos apagado
  if ($sock(cciudadelas)) { did -b jugar 1,2,3,20 | did -o jugar 7 1 $texto(7) }

  ;configuración
  if (%cciudadelas.f.listados) { did -c jugar 19 }

  var %x = 0 , %total = $findfile(ciudadelas,msgs.*,0)
  while (%x < %total) {

    inc %x

    var %archivo = $nopath($findfile(ciudadelas,msgs.*,%x))
    var %linea = $gettok( %archivo ,2,46)
    did -a jugar 20 %linea

    ;aprovechamos para seleccionar el que toque...
    if (%cciudadelas.f.msgs == %archivo) { did -c jugar 20 %x }

  }

}


on 1:dialog:jugar:sclick:20:{

  ;si hay ventana de partidas, guardamos nombre para renombrar luego
  if ( $window( $ventana(partidas) ) ) { var %ventanavieja = $ventana(partidas) }

  %cciudadelas.f.msgs = msgs. $+ $did(jugar,20).seltext $+ .txt
  window -c @mensajes
  window -hl @mensajes
  loadbuf @mensajes ciudadelas/ $+ %cciudadelas.f.msgs

  ;recargamos distritos con nueva traducción
  window -c @distritos
  window -hl @distritos
  loadbuf -e @distritos ciudadelas/distritos.txt

  ;si hay ventana de partidas, la renombramos
  if (%ventanavieja) { renwin %ventanavieja $ventana(partidas) }

  dialog -x jugar
  timer 1 0 dibuja_inicio

}

;$valida_nombre(nombre) -> nos devuelve un nombre válido
alias valida_nombre {
  ;basicamente, evitamos nombre inferiores a 3 caracteres para que no nos pisen registros internos
  if ( $len($1) < 3 ) { return  $1 $+ $str(_,2) }
  else { return $1 }
}

on 1:dialog:jugar:close:0:{
  %cciudadelas.f.host = $did(jugar,1)
  %cciudadelas.f.puerto = $did(jugar,2)
  %cciudadelas.f.nombre = $valida_nombre($did(jugar,3))
  %sciudadelas.f.puerto = $did(jugar,11)
  %sciudadelas.f.partida = $did(jugar,12)
  %sciudadelas.f.nat = $did(jugar,23)
}

on 1:dialog:jugar:sclick:*:{

  %cciudadelas.f.host = $did(jugar,1)
  %cciudadelas.f.puerto = $did(jugar,2)
  %cciudadelas.f.nombre = $valida_nombre($did(jugar,3))
  %sciudadelas.f.puerto = $did(jugar,11)
  %sciudadelas.f.partida = $did(jugar,12)
  %sciudadelas.f.nat = $did(jugar,23)

  if ( $did == 7) {
    if ($sock(cciudadelas)) {
      ;si estábamos en una partida, apagamos
      sockclose cciudadelas
      window -c @chat
      window -c $ventana(mano)
      window -c $ventana(mesa)
      window -c $ventana(personajes)
      carga_datos
      timer 1 0 dibuja_inicio
    }
    else {
      ;si no estábamos jugando, conectamos
      ;previa comprobación y actualización de las variables
      if ( (!%cciudadelas.f.host) || (!%cciudadelas.f.puerto) || (!%cciudadelas.f.nombre) ) { timer 1 0 dibuja_inicio }
      else {
        conecta %cciudadelas.f.host %cciudadelas.f.puerto
        dibuja_conectando
      }
    }
  }

  if ($did == 8) { //url $texto(256) }

  ;control de conexión a servidor central
  if ($did == 19) { 
    if (%cciudadelas.f.listados) {
      unset %cciudadelas.f.listados
      ;desconectamos del servidor central
      sockclose listados 
      ;si hay ventana de partidas, la cerramos
      window -c $ventana(partidas)
    }
    else {
      %cciudadelas.f.listados = 1 
      conecta_servidor_central
    }
  }

}

alias ventana {

  if ($1 == mesa) { return @ $+ $texto(204) }
  if ($1 == mano) { return @ $+ $texto(205) }
  if ($1 == personajes) { return @ $+ $texto(160) }
  if ($1 == hechicero) { return @ $+ $texto(144) }
  if ($1 == partidas) { return @ $+ $texto(64) }
  if ($1 == mazo) { return @ $+ $texto(249) }

}

;dibuja_mazo <listaIDsDistritos> -> dibuja una ventana @mazo en la que se muestran
;los distritos disponibles y su número. Para maravilla Faro.
alias dibuja_mazo {


  ;creamos ventana @Mazo y su ventana de control de coordenadas @cartas_mazo
  window -c $ventana(mazo)
  window -pbk[0] +d $ventana(mazo) 1 1 %cciudadelas.f.w %cciudadelas.f.w 
  drawfill -r $ventana(mazo) 32768 1 1 1

  window -c @cartas_mazo
  window -hl @cartas_mazo

  drawrect -rdf $ventana(mazo) 11595006 1 820 390 130 210 30 30
  drawtext $ventana(mazo) 1 arial 18 826 400  $texto(225)
  encuadra $ventana(mazo) 830 421 120 12 arial 12 $texto(250)

  var %c = 0 , %total = $numtok($1-,32)
  while (%c < %total) {
    inc %c
    var %id = $gettok( $gettok($1-,%c,32) ,1,58)
    ;miramos primera fila, si hay menos de 8 cartas dibujamos ahí, si no pasamos a siguiente y repetimos
    var %l = 1
    while (%l) {
      var %nc = $columnas(%l,@cartas_mazo)
      if (%nc < 8) {
        dibuja %l %id mazo | unset %l
      }
      else { inc %l }
    }
  }

}

;cuadradito <id_distrito> -> dibuja en @mazo un cuadrito en la carta grande con el número de cartas iguales a id disponibles
alias cuadradito {
  var %token = $matchtok(%cciudadelas.v.listaIDS, $1 $+ : ,1,32)
  if ( %token ) {
    var %numero = $gettok(%token,2,58)

    drawrect -rf $ventana(mazo) 11595006 1 925 30 20 20
    drawtext $ventana(mazo) 1 arial 20 929 28 %numero
  }
}

