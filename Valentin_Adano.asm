.data
# Espacio para listas y mensajes
slist:    .word 0       # Lista de nodos liberados
cclist:   .word 0       # Lista de categorias
wclist:   .word 0       # Categoria seleccionada
schedv:   .space 32     # Vector de direcciones para las funciones del menu
menu:     .asciiz "Menu:\n1. Nueva categoria\n2. Siguiente categoria\n3. Categoria anterior\n4. Listar categorias\n5. Borrar categoria actual\n6. Anexar objeto a categoria\n7. Listar objetos\n8. Borrar objeto\n0. Salir\nSeleccione: "
error101: .asciiz "Error: Opcion no valida\n"
error201: .asciiz "Error: No hay categorias\n"
error202: .asciiz "Error: Solo hay una categoria\n"
success:  .asciiz "Operacion exitosa\n"
catName:  .asciiz "Ingrese el nombre de la categoria: "
objName:  .asciiz "Ingrese el nombre del objeto: "
idObj:    .asciiz "Ingrese el ID del objeto: "
return:   .asciiz "\n"

.text
.globl main

# Funcion principal
main:
    # Inicializacion del vector de funciones
    la $t0, schedv
    la $t1, newcategory
    sw $t1, 0($t0)
    la $t1, nextcategory
    sw $t1, 4($t0)
    la $t1, prevcategory
    sw $t1, 8($t0)
    la $t1, listcategories
    sw $t1, 12($t0)
    la $t1, delcategory
    sw $t1, 16($t0)
    la $t1, newobject
    sw $t1, 20($t0)
    la $t1, listobjects
    sw $t1, 24($t0)
    la $t1, delobject
    sw $t1, 28($t0)

    # Menu principal
menu_loop:
    li $v0, 4
    la $a0, menu
    syscall            # Mostrar menu

    li $v0, 5
    syscall            # Leer opcion del usuario
    move $t1, $v0

    blt $t1, 0, invalid_option
    bgt $t1, 8, invalid_option

    # Llamar a la funcion correspondiente en schedv
    la $t0, schedv
    sll $t1, $t1, 2    # Multiplicar opcion por 4 (tamaño de palabra)
    lw $t2, 0($t1)     # Cargar direccion de funcion
    jalr $t2           # Llamar a la funcion

    j menu_loop

invalid_option:
    li $v0, 4
    la $a0, error101
    syscall
    j menu_loop

# Funcion: Crear nueva categoria
newcategory:
addiu $sp, $sp, -4
sw $ra, 4($sp)
la $a0, catName # input category name
jal getblock
move $a2, $v0 # $a2 = *char to category name
la $a0, cclist # $a0 = list
li $a1, 0 # $a1 = NULL
jal addnode
lw $t0, wclist
bnez $t0, newcategory_end
sw $v0, wclist # update working list if was NULL
newcategory_end:
li $v0, 0 # return success
lw $ra, 4($sp)
addiu $sp, $sp, 4
jr $ra

# Funcion: Siguiente categoria
nextcategory:
    lw $t0, wclist
    beqz $t0, no_categories
    lw $t1, 12($t0)    # Cargar siguiente categoria
    sw $t1, wclist     # Actualizar categoria seleccionada
    j success_msg

no_categories:
    li $v0, 4
    la $a0, error201
    syscall
    jr $ra

success_msg:
    li $v0, 4
    la $a0, success
    syscall
    jr $ra

# Funcion: Categoria anterior
prevcategory:
    lw $t0, wclist
    beqz $t0, no_categories
    lw $t1, 0($t0)     # Cargar categoria anterior
    sw $t1, wclist     # Actualizar categoria seleccionada
    j success_msg

# Funcion: Listar categorias
listcategories:
    lw $t0, cclist
    beqz $t0, no_categories
    move $t1, $t0

list_loop:
    li $v0, 4
    beq $t1, $t0, show_current
    syscall
    lw $t1, 12($t1)
    bne $t1, $t0, list_loop

show_current:
    li $v0, 4
    la $a0, success
    syscall
    jr $ra

# Funcion: Borrar categoria actual
delcategory:
    lw $t0, wclist          # Cargar la categoria seleccionada
    beqz $t0, no_categories # Error si no hay categorias

    lw $t1, 4($t0)          # Verificar si tiene objetos enlazados
    bnez $t1, delete_objects

delete_category:
    lw $t2, 0($t0)          # Cargar categoria anterior
    lw $t3, 12($t0)         # Cargar categoria siguiente

    # Actualizar punteros de la lista circular
    sw $t3, 12($t2)
    sw $t2, 0($t3)

    # Si se borra la última categoria, nulificar punteros
    beq $t0, $t3, clear_wclist
    sw $t3, wclist          # Actualizar categoria seleccionada
    j free_category

clear_wclist:
    sw $zero, wclist
    sw $zero, cclist
    j free_category

delete_objects:
    lw $t1, 4($t0)          # Primer objeto enlazado
delete_objects_loop:
    beqz $t1, delete_category
    move $a0, $t1           # Direccion del objeto
    la $a1, 4($t0)          # Lista de objetos
    jal delnode             # Borrar nodo del objeto
    j delete_objects_loop

free_category:
    move $a0, $t0           # Direccion de la categoria
    la $a1, cclist          # Lista de categorias
    jal delnode             # Liberar nodo de la categoria
    j success_msg

# Funcion: Crear un objeto en la categoria actual
newobject:
    lw $t0, wclist          # Cargar la categoria seleccionada
    beqz $t0, no_categories # Error si no hay categorias

    la $a0, objName         # Solicitar nombre del objeto
    jal getblock            # Obtener bloque de memoria
    move $a2, $v0           # Guardar el bloque en $a2

    lw $a0, 4($t0)          # Cargar lista de objetos de la categoria
    li $a1, 0               # Nuevo nodo (sin enlace previo)
    jal addnode             # Agregar el nuevo objeto a la lista

    sw $v0, 4($t0)          # Actualizar puntero de la lista en la categoria
    j success_msg

# Funcion: Listar objetos de la categoria actual
listobjects:
    lw $t0, wclist          # Cargar la categoria seleccionada
    beqz $t0, no_categories # Error si no hay categorias

    lw $t1, 4($t0)          # Cargar lista de objetos
    beqz $t1, no_objects    # Error si no hay objetos

list_objects_loop:
    li $v0, 4
    la $a0, success         # Imprimir el objeto actual (simulacion)
    syscall
    lw $t1, 12($t1)         # Siguiente objeto
    lw $t2, 4($t0)          # Cargar el valor de 4($t0) en $t2
    bne $t1, $t2, list_objects_loop  # Comparar $t1 con $t2
    j success_msg

no_objects:
    li $v0, 4
    la $a0, error202        # Mensaje de error si no hay objetos
    syscall
    jr $ra

# Funcion: Borrar un objeto de la categoria actual
delobject:
    lw $t0, wclist          # Cargar la categoria seleccionada
    beqz $t0, no_categories # Error si no hay categoriggas

    lw $t1, 4($t0)          # Cargar lista de objetos
    beqz $t1, no_objects    # Error si no hay objetos

    li $v0, 4
    la $a0, idObj           # Solicitar el ID del objeto a borrar
    syscall

    li $v0, 5
    syscall                 # Leer el ID del usuario
    move $t2, $v0           # Guardar el ID en $t2

search_object:
    lw $t3, 8($t1)          # Cargar ID del objeto actual
    beq $t3, $t2, found_object
    lw $t1, 12($t1)         # Siguiente objeto
    lw $t2, 4($t0)          # Cargar el valor de 4($t0) en $t2
    bne $t1, $t2, search_object  # Comparar $t1 con $t2
    j object_not_found

found_object:
    move $a0, $t1           # Direccion del objeto a borrar
    la $a1, 4($t0)          # Lista de objetos
    jal delnode             # Borrar el nodo
    j success_msg

object_not_found:
    li $v0, 4
    la $a0, error202        # Mensaje de error si no se encuentra el objeto
    syscall
    jr $ra

getblock:
addi $sp, $sp, -4
sw $ra, 4($sp)
li $v0, 4
syscall
jal smalloc
move $a0, $v0
li $a1, 16
li $v0, 8
syscall
move $v0, $a0
lw $ra, 4($sp)
addi $sp, $sp, 4
jr $ra

    
    
    # a0: list address
# a1: NULL if category, node address if object
# v0: node address added
addnode:
addi $sp, $sp, -8
sw $ra, 8($sp)
sw $a0, 4($sp)
jal smalloc
sw $a1, 4($v0) # set node content
sw $a2, 8($v0)
lw $a0, 4($sp)
lw $t0, ($a0) # first node address
beqz $t0, addnode_empty_list
addnode_to_end:
lw $t1, ($t0) # last node address
# update prev and next pointers of new node
sw $t1, 0($v0)
sw $t0, 12($v0)
# update prev and first node to new node
sw $v0, 12($t1)
sw $v0, 0($t0)
j addnode_exit
addnode_empty_list:
sw $v0, ($a0)
sw $v0, 0($v0)
sw $v0, 12($v0)
addnode_exit:
lw $ra, 8($sp)
addi $sp, $sp, 8
jr $ra
# a0: node address to delete
# a1: list address where node is deleted
delnode:
addi $sp, $sp, -8
sw $ra, 8($sp)
sw $a0, 4($sp)
lw $a0, 8($a0) # get block address
jal sfree # free block
lw $a0, 4($sp) # restore argument a0
lw $t0, 12($a0) # get address to next node of a0
node:
beq $a0, $t0, delnode_point_self
lw $t1, 0($a0) # get address to prev node
sw $t1, 0($t0)
sw $t0, 12($t1)
lw $t1, 0($a1) # get address to first node
again:
bne $a0, $t1, delnode_exit
sw $t0, ($a1) # list point to next node
j delnode_exit
delnode_point_self:
sw $zero, ($a1) # only one node
delnode_exit:
jal sfree
lw $ra, 8($sp)
addi $sp, $sp, 8
jr $ra


# a0: msg to ask
# v0: block address allocated with string

smalloc:
lw $t0, slist
beqz $t0, sbrk
move $v0, $t0
lw $t0, 12($t0)
sw $t0, slist
jr $ra

sbrk:
li $a0, 16 # node size fixed 4 words
li $v0, 9
syscall # return node address in v0
jr $ra

sfree:
lw $t0, slist
sw $t0, 12($a0)
sw $a0, slist # $a0 node address in unused list
jr $ra