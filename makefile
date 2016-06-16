all:	
	echo 'floppya: image=a.img, status=inserted' > bochsrc
	echo 'ata0-master: type=disk, path="80m.img", mode=flat' >> bochsrc
	#echo 'clock: sync=realtime, time0=local' >> bochsrc
	nasm andyos.asm -o a.img

clean:
	rm -f a.img bochsrc

run:
	bochs -q
