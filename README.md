![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)



# PICOPRESENT
### Designing and Building a Custom Cryptographic ASIC



Author: Jonathan Bercovici  


<img width="3467" height="3254" alt="gds_render" src="https://github.com/user-attachments/assets/6de77ddb-b7df-4cf2-ac88-40b4a6a77397" />


---



# The Idea

I was given an amazing oppurtinity by hackclub to get a slot on the on the wafer.space GF180MCU Run 3 MPW (multi-project-wafer) from DeepAI. When I first found this out i was in shock. In the past i had built very simple cpus in verilog, but now since i had the chance to have it in real life i wanted to build something that is acutally usefull. I didnt want to just build another cpu as that has been done so so so many times i wanted something oringial. A few ideas that i had at first was a driver for an led board ( i know this sounds pretty dull) and then another one was a vga clk, But all of these were pretty boring. I wanted something much cooler. Then it hit me. 

A crypto graphic acclerater


# Research & Planning

## Choosing PRESENT-80

I orignally chose the present 80 algorithm beccasue it is basically impossible to break. Right now i dont think there are any known ways to crack it apart from just fully brute forcing it. Another reason why it is so good is that it runs on very little hardware

<img width="1024" height="448" alt="image" src="https://github.com/user-attachments/assets/2b651f3b-4063-44e3-a34b-723a76058b67" />
This is a simple overview of the of the encypption used in pico presnet. On either side you can see the two simaltanius things happenign at the same time. The one of the left is the main encpytoin and the part on the right is the jey shuffler. 

# How to use

There is a python scrpit that allows you to connect Picopresnet to your computer. You can then upload a file and it encypts it then sends it back
<img width="640" height="518" alt="image" src="https://github.com/user-attachments/assets/19022af7-f92e-4d03-a0db-9dd94e0a12a2" />





