# Power Board

1. Print out the CAD drawings of the panel from the repo. Use them as a template to cut the ABS sheets to size.

![cad](../_media/power1.jpeg)

2. If you don't have an apropriate power saw like a band saw, a speciality PVC saw can purchased on Amazon.

![saw](../_media/power2.jpeg)

3. Use masking tape to layout the holes for the power supplies. 

![tape](../_media/power3.jpeg)

4. We found it helpful to draw the components that mount on the main aluminum faceplate on the masking tape so you know what space they will occupy.

![layout](../_media/power4.jpeg)

5. Mount the supplies using double sided tape, short standoffs, and M3 bolts and nuts. The 5v supplies will hang off the panel about 1", and will extend under the USB panel. This is by design. Orient the output side of the supply towards the USB panel, and the input side towards the case.

![supplies](../_media/power5.jpeg)
<div class="caption">Note: relay in photo is not inverted. Photo was taken before modification added in step 13</div>


6. The double sided foam tape and standoffs will allow room for the screws that mount the 24vdc supply, which go into the threaded inserts on the bottom of the supply.

![tape](../_media/power6.jpeg)

7. The 24vdc supply mounts on the backside of the panel, with the terminals towards the bottom (closest to the AC input and switches).

![large](../_media/power7.jpeg)

8. Wire two positive and two negative wires to the output of the 24vdc supply. One set of wires go to the NO contacts of the relay (terminal 2 red, terminal 6 black). The second positive goes to input one of the switch (terminal 13), and output one of the switch (terminal 14) goes to the coil of the relay (terminal 0). The second negative goes to the relay coil (terminal 1).

![wiring](../_media/power8.jpeg)

9. Heatshrink crimp forks are recommended for larger guage wire and large screw terminals.

![forks](../_media/power9.jpeg)

10. Crimp ferules work great for smaller gauge wires connecting to smaller screw terminals.

![ferule](../_media/power10.jpeg)

11. Cut the majority of the wire from the XT90 input plug, leaving about 4 - 5 inches. Crimp spade terminals on and use heatshrink to reinforce the connection.

![dc](../_media/power11.jpeg)

12. Daisy chain the power input from the relay through the 5vdc power supplies and to the DC input via the switch. The DC input feeds from one end of the circuit, and the 24vdc power supply from the other, however they cannot be live at the same time due to the switch and relay. See schematic below.

* Run a pair of wires from the output of the relay NO contacts (terminals 4 red, terminal 8 black) to the input of the first 5v supply. 

* Continue wiring around the outside of the panel connecting a small set of jumpers from the input of the first 5vdc supply, to the input of the second 5vdc supply. 

* Connect the positive (red) of the second 5vdc supply input to a 3 way connection - one feeding a set of jumpers over to the 12vdc supply on the USB panel, and the other to the second output on the switch (terminal 24). We recommend using a spade terminal for the USB panel feed side of the connection so the boards can be disconnected if necessary.

* Connect the negative (black) of the second 5vdc supply input to a 3 way connection - one feeding a set the jumpers over to the 12vdc supply on the USB panel, and the other to black of the XT90 input. 

* Finally, connect a wire from the positive of the XT90 connector to the second input of the switch (terminal 23).

![wiring2](../_media/power12.jpeg)
<div class="caption">Note: relay in photo is not inverted. Photo was taken before modification added in step 13</div>

![wiring2](../_media/power12.1.jpeg)


13. To make it easer to slide the assembly in and out of the case, invert the relay and notch the panel to allow the screw terminals to recess through the board. The terminals can now be connected from the inside of the panel facing out, so they don't catch on the case frame.

![relay](../_media/power13.jpeg)

14. Cut a similar notch on the other end of the panel to allow the 120vac input wires to lay inside the permiter of the panel.

![notch](../_media/power14.jpeg)

15. Heatshrink the 120vac wires and secure them to the panel with a small cable tie to pull them underneath. Add spade connectors and connect to the fused power switch.

![line](../_media/power15.jpeg)