all:	
	echo 'floppya: image="a.img", status=inserted' > bochsrc
	echo 'clock: sync=realtime, time0=local' >> bochsrc
	nasm andyos.asm -o a.img

clean:
	rm -f a.img bochsrc

run:
	bochs -q
